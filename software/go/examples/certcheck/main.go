// Command certcheck reports TLS certificate expiry for a list of hosts.
//
//	certcheck -warn-days 21 example.com example.org:8443
//	certcheck -file hosts.txt -output json
//
// It connects to each host, verifies the certificate chain and hostname the
// way a client would, and reports the days until expiry. It exits 1 if any
// certificate fails verification or expires within -warn-days, so it can run
// from cron or CI and alert before an outage.
package main

import (
	"bufio"
	"context"
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Result is the outcome for one target.
type Result struct {
	Target   string   `json:"target"`
	OK       bool     `json:"ok"`
	DaysLeft *int     `json:"days_left"`
	Expires  string   `json:"expires,omitempty"`
	Issuer   string   `json:"issuer,omitempty"`
	Names    []string `json:"names"`
	Error    string   `json:"error,omitempty"`
}

// Options control a check.
type Options struct {
	WarnDays int
	Timeout  time.Duration
	Roots    *x509.CertPool // nil means the system's trusted CAs
	Now      func() time.Time
}

// parseTarget turns "host", "host:port", "[ipv6]", or "[ipv6]:port" into a
// host and port, defaulting to 443.
func parseTarget(target string) (host, port string) {
	if strings.HasPrefix(target, "[") && strings.HasSuffix(target, "]") {
		return strings.Trim(target, "[]"), "443"
	}
	if h, p, err := net.SplitHostPort(target); err == nil {
		return h, p
	}
	return target, "443"
}

// Check checks one target. Network and certificate problems are reported in
// the Result, not returned as errors.
func Check(ctx context.Context, target string, opts Options) Result {
	res := Result{Target: target, Names: []string{}}
	host, port := parseTarget(target)

	// Verifying the chain against trusted CAs and the name against the
	// certificate is tls's default: exactly what clients do.
	dialer := &tls.Dialer{
		NetDialer: &net.Dialer{Timeout: opts.Timeout},
		Config:    &tls.Config{ServerName: host, RootCAs: opts.Roots, MinVersion: tls.VersionTLS12},
	}
	conn, err := dialer.DialContext(ctx, "tcp", net.JoinHostPort(host, port))
	if err != nil {
		// Expired, untrusted, or wrong hostname: report why.
		if verr, ok := errors.AsType[*tls.CertificateVerificationError](err); ok {
			res.Error = "verification failed: " + verr.Err.Error()
		} else {
			res.Error = err.Error()
		}
		return res
	}
	defer func() { _ = conn.Close() }()

	leaf := conn.(*tls.Conn).ConnectionState().PeerCertificates[0]
	days := int(leaf.NotAfter.Sub(opts.Now()).Hours() / 24)
	res.DaysLeft = &days
	res.Expires = leaf.NotAfter.UTC().Format(time.RFC3339)
	res.Issuer = leaf.Issuer.String()
	res.Names = append(res.Names, leaf.DNSNames...)
	for _, ip := range leaf.IPAddresses {
		res.Names = append(res.Names, ip.String())
	}
	res.OK = days >= opts.WarnDays
	if !res.OK {
		res.Error = fmt.Sprintf("expires in %d days (warning at %d)", days, opts.WarnDays)
	}
	return res
}

// CheckAll checks targets concurrently, at most `workers` at a time, and
// returns results in the same order as the targets.
func CheckAll(ctx context.Context, targets []string, opts Options, workers int) []Result {
	results := make([]Result, len(targets))
	sem := make(chan struct{}, workers)
	var wg sync.WaitGroup
	for i, t := range targets {
		wg.Go(func() {
			sem <- struct{}{}
			defer func() { <-sem }()
			results[i] = Check(ctx, t, opts)
		})
	}
	wg.Wait()
	return results
}

func readTargets(path string) ([]string, error) {
	f, err := os.Open(path) //nolint:gosec // reading the file the user named is the point
	if err != nil {
		return nil, err
	}
	defer func() { _ = f.Close() }()
	var targets []string
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		if line := strings.TrimSpace(scanner.Text()); line != "" && !strings.HasPrefix(line, "#") {
			targets = append(targets, line)
		}
	}
	return targets, scanner.Err()
}

func run(ctx context.Context, args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("certcheck", flag.ContinueOnError)
	fs.SetOutput(stderr)
	file := fs.String("file", "", "read targets from a file, one per line")
	warnDays := fs.Int("warn-days", 21, "fail if a certificate expires within this many days")
	timeout := fs.Duration("timeout", 5*time.Second, "timeout per host")
	caFile := fs.String("ca-file", "", "trust this CA bundle instead of the system's")
	output := fs.String("output", "text", "text or json")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	targets := fs.Args()
	if *file != "" {
		more, err := readTargets(*file)
		if err != nil {
			fmt.Fprintln(stderr, "certcheck:", err)
			return 2
		}
		targets = append(targets, more...)
	}
	if len(targets) == 0 {
		fmt.Fprintln(stderr, "certcheck: give at least one target, or -file")
		return 2
	}

	opts := Options{WarnDays: *warnDays, Timeout: *timeout, Now: time.Now}
	if *caFile != "" {
		pem, err := os.ReadFile(*caFile)
		if err != nil {
			fmt.Fprintln(stderr, "certcheck:", err)
			return 2
		}
		opts.Roots = x509.NewCertPool()
		if !opts.Roots.AppendCertsFromPEM(pem) {
			fmt.Fprintln(stderr, "certcheck: no certificates in", *caFile)
			return 2
		}
	}

	results := CheckAll(ctx, targets, opts, 16)
	allOK := true
	for _, r := range results {
		allOK = allOK && r.OK
	}
	if *output == "json" {
		enc := json.NewEncoder(stdout)
		enc.SetIndent("", "  ")
		if err := enc.Encode(results); err != nil {
			fmt.Fprintln(stderr, "certcheck:", err)
			return 2
		}
	} else {
		for _, r := range results {
			state, detail := "FAIL", ""
			if r.OK {
				state = "OK  "
			}
			if r.DaysLeft != nil {
				detail = fmt.Sprintf("%d days, until %s", *r.DaysLeft, r.Expires)
			}
			fmt.Fprintln(stdout, strings.TrimRight(fmt.Sprintf("%s  %s  %s  %s", state, r.Target, detail, r.Error), " "))
		}
	}
	if !allOK {
		return 1
	}
	return 0
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	code := run(ctx, os.Args[1:], os.Stdout, os.Stderr)
	stop()
	os.Exit(code)
}
