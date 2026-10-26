package main

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"math/big"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// tlsServer starts a TLS server whose self-signed certificate for 127.0.0.1
// expires in `days`. It returns the server's address and a pool trusting it.
func tlsServer(t *testing.T, days int) (string, *x509.CertPool, []byte) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	template := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "test-server"},
		NotBefore:             now.Add(-time.Hour),
		NotAfter:              now.Add(time.Duration(days) * 24 * time.Hour),
		IPAddresses:           []net.IP{net.ParseIP("127.0.0.1")},
		DNSNames:              []string{"localhost"},
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
		IsCA:                  true,
	}
	der, err := x509.CreateCertificate(rand.Reader, template, template, &key.PublicKey, key)
	if err != nil {
		t.Fatal(err)
	}
	cert, err := x509.ParseCertificate(der)
	if err != nil {
		t.Fatal(err)
	}

	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	srv.TLS = &tls.Config{
		Certificates: []tls.Certificate{{Certificate: [][]byte{der}, PrivateKey: key}},
		MinVersion:   tls.VersionTLS12,
	}
	srv.Config.ErrorLog = nil
	srv.StartTLS()
	t.Cleanup(srv.Close)

	pool := x509.NewCertPool()
	pool.AddCert(cert)
	pemBytes := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
	return srv.Listener.Addr().String(), pool, pemBytes
}

func opts(pool *x509.CertPool) Options {
	return Options{WarnDays: 21, Timeout: 2 * time.Second, Roots: pool, Now: time.Now}
}

func TestParseTarget(t *testing.T) {
	cases := map[string][2]string{
		"example.com":        {"example.com", "443"},
		"example.com:8443":   {"example.com", "8443"},
		"[2001:db8::1]:8443": {"2001:db8::1", "8443"},
		"[2001:db8::1]":      {"2001:db8::1", "443"},
	}
	for in, want := range cases {
		if h, p := parseTarget(in); h != want[0] || p != want[1] {
			t.Errorf("parseTarget(%q) = %q, %q; want %q", in, h, p, want)
		}
	}
}

func TestValidCertificate(t *testing.T) {
	addr, pool, _ := tlsServer(t, 90)
	r := Check(t.Context(), addr, opts(pool))
	if !r.OK {
		t.Fatalf("want OK, got %+v", r)
	}
	if *r.DaysLeft < 88 || *r.DaysLeft > 90 {
		t.Errorf("days left = %d, want about 90", *r.DaysLeft)
	}
	if r.Issuer != "CN=test-server" {
		t.Errorf("issuer = %q", r.Issuer)
	}
	if strings.Join(r.Names, ",") != "localhost,127.0.0.1" {
		t.Errorf("names = %v", r.Names)
	}
}

func TestExpiringCertificateFails(t *testing.T) {
	addr, pool, _ := tlsServer(t, 5)
	r := Check(t.Context(), addr, opts(pool))
	if r.OK || !strings.Contains(r.Error, "expires in") {
		t.Fatalf("want an expiry failure, got %+v", r)
	}
}

func TestUntrustedCertificateFails(t *testing.T) {
	addr, _, _ := tlsServer(t, 90)
	r := Check(t.Context(), addr, opts(nil)) // system CAs don't trust the test cert
	if r.OK || !strings.HasPrefix(r.Error, "verification failed") {
		t.Fatalf("want a verification failure, got %+v", r)
	}
}

func TestConnectionRefused(t *testing.T) {
	l, err := (&net.ListenConfig{}).Listen(t.Context(), "tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := l.Addr().String()
	l.Close()
	if r := Check(t.Context(), addr, opts(nil)); r.OK || r.Error == "" {
		t.Fatalf("want a connection error, got %+v", r)
	}
}

func TestRunExitCodes(t *testing.T) {
	addr, _, pemBytes := tlsServer(t, 90)
	ca := filepath.Join(t.TempDir(), "ca.pem")
	if err := os.WriteFile(ca, pemBytes, 0o600); err != nil {
		t.Fatal(err)
	}
	var out, errOut bytes.Buffer
	if code := run(t.Context(), []string{"-ca-file", ca, addr}, &out, &errOut); code != 0 {
		t.Fatalf("exit %d, stdout %q, stderr %q", code, out.String(), errOut.String())
	}
	if !strings.HasPrefix(out.String(), "OK") {
		t.Errorf("output %q", out.String())
	}
	if code := run(t.Context(), []string{"-ca-file", ca, "-warn-days", "365", addr}, &out, &errOut); code != 1 {
		t.Errorf("exit %d, want 1 inside the warning window", code)
	}
	if code := run(t.Context(), nil, &out, &errOut); code != 2 {
		t.Errorf("exit %d, want 2 with no targets", code)
	}
}
