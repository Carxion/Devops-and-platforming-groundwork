// Command logstats summarizes web access logs (nginx and Apache combined format).
//
//	logstats /var/log/nginx/access.log /var/log/nginx/access.log.2.gz
//	zcat access.log.*.gz | logstats -output json
//	logstats -max-error-ratio 0.01 access.log    # exit 1 if over 1% 5xx
//
// It streams the input line by line, so it handles logs larger than memory.
package main

import (
	"bufio"
	"compress/gzip"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"math"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// 203.0.113.9 - - [13/Oct/2026:08:00:01 +0000] "GET /items/17 HTTP/1.1" 200 512 "-" "curl/8.5.0"
var (
	line = regexp.MustCompile(
		`^(?P<ip>\S+) \S+ \S+ \[(?P<time>[^\]]+)\] "(?P<method>[A-Z]+) (?P<path>\S+)[^"]*" (?P<status>\d{3}) (?P<bytes>\d+|-)`)
	uuidSegment = regexp.MustCompile(`/[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}(/|$)`)
	// RE2 has no lookahead, so match the following "/" or end and put it back.
	numericSegment = regexp.MustCompile(`/\d+(/|$)`)
)

// route collapses IDs so /items/17 and /items/42 count as one route: /items/{id}.
func route(path string) string {
	path, _, _ = strings.Cut(path, "?")
	path = uuidSegment.ReplaceAllString(path, "/{uuid}$1")
	// Adjacent IDs (/17/42) share a "/", so one pass can miss the second: repeat.
	for {
		next := numericSegment.ReplaceAllString(path, "/{id}$1")
		if next == path {
			return path
		}
		path = next
	}
}

// Stats accumulates counts from log lines.
type Stats struct {
	Requests, Unparsed, BytesSent                    int
	Status, Routes, Clients, PerMinute, ServerErrors map[string]int
}

// NewStats returns empty Stats.
func NewStats() *Stats {
	return &Stats{
		Status: map[string]int{}, Routes: map[string]int{}, Clients: map[string]int{},
		PerMinute: map[string]int{}, ServerErrors: map[string]int{},
	}
}

// Add counts one log line.
func (s *Stats) Add(text string) {
	m := line.FindStringSubmatch(text)
	if m == nil {
		s.Unparsed++
		return
	}
	get := func(name string) string { return m[line.SubexpIndex(name)] }
	s.Requests++
	code := get("status")
	key := get("method") + " " + route(get("path"))
	s.Status[code]++
	s.Routes[key]++
	s.Clients[get("ip")]++
	if t := get("time"); len(t) >= 17 {
		s.PerMinute[t[:17]]++ // 13/Oct/2026:08:00
	}
	if n, err := strconv.Atoi(get("bytes")); err == nil {
		s.BytesSent += n
	}
	if strings.HasPrefix(code, "5") {
		s.ServerErrors[code+" "+key]++
	}
}

// ErrorRatio is the share of requests that returned 5xx.
func (s *Stats) ErrorRatio() float64 {
	if s.Requests == 0 {
		return 0
	}
	errors := 0
	for code, n := range s.Status {
		if strings.HasPrefix(code, "5") {
			errors += n
		}
	}
	return float64(errors) / float64(s.Requests)
}

// Pair is a name and a count; it encodes to JSON as ["name", count].
type Pair struct {
	Name  string
	Count int
}

// MarshalJSON encodes the pair as a two-element array.
func (p Pair) MarshalJSON() ([]byte, error) { return json.Marshal([]any{p.Name, p.Count}) }

// top returns the n largest counts, ties broken by name.
func top(counts map[string]int, n int) []Pair {
	pairs := make([]Pair, 0, len(counts))
	for k, v := range counts {
		pairs = append(pairs, Pair{k, v})
	}
	sort.Slice(pairs, func(i, j int) bool {
		if pairs[i].Count != pairs[j].Count {
			return pairs[i].Count > pairs[j].Count
		}
		return pairs[i].Name < pairs[j].Name
	})
	return pairs[:min(n, len(pairs))]
}

// Summary is the report, in the same shape as the Python version's JSON.
type Summary struct {
	Requests        int            `json:"requests"`
	UnparsedLines   int            `json:"unparsed_lines"`
	BytesSent       int            `json:"bytes_sent"`
	ErrorRatio      float64        `json:"error_ratio"`
	PeakMinute      *Peak          `json:"peak_minute"`
	Status          map[string]int `json:"status"`
	TopRoutes       []Pair         `json:"top_routes"`
	TopClients      []Pair         `json:"top_clients"`
	TopServerErrors []Pair         `json:"top_server_errors"`
}

// Peak is the busiest minute.
type Peak struct {
	Minute   string `json:"minute"`
	Requests int    `json:"requests"`
}

// Summary builds the report, keeping the top n of each list.
func (s *Stats) Summary(n int) Summary {
	sum := Summary{
		Requests: s.Requests, UnparsedLines: s.Unparsed, BytesSent: s.BytesSent,
		ErrorRatio: math.Round(s.ErrorRatio()*1e4) / 1e4,
		Status:     s.Status,
		TopRoutes:  top(s.Routes, n), TopClients: top(s.Clients, n),
		TopServerErrors: top(s.ServerErrors, n),
	}
	if busiest := top(s.PerMinute, 1); len(busiest) == 1 {
		sum.PeakMinute = &Peak{busiest[0].Name, busiest[0].Count}
	}
	return sum
}

// analyze reads every line from r into s.
func analyze(r io.Reader, s *Stats) error {
	scanner := bufio.NewScanner(r)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024) // allow lines up to 1 MiB
	for scanner.Scan() {
		s.Add(scanner.Text())
	}
	return scanner.Err()
}

// analyzeFile reads one file, decompressing it if the name ends in .gz.
func analyzeFile(path string, s *Stats) error {
	f, err := os.Open(path) //nolint:gosec // reading the file the user named is the point
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()
	var r io.Reader = f
	if strings.HasSuffix(path, ".gz") {
		gz, err := gzip.NewReader(f)
		if err != nil {
			return fmt.Errorf("%s: %w", path, err)
		}
		defer func() { _ = gz.Close() }()
		r = gz
	}
	return analyze(r, s)
}

func renderText(w io.Writer, s Summary) {
	fmt.Fprintf(w, "Requests: %d, 5xx ratio: %.2f%%, data sent: %.1f MB, unparsed lines: %d\n",
		s.Requests, s.ErrorRatio*100, float64(s.BytesSent)/1_048_576, s.UnparsedLines)
	if s.PeakMinute != nil {
		fmt.Fprintf(w, "Peak minute: %s (%d)\n", s.PeakMinute.Minute, s.PeakMinute.Requests)
	}
	codes := make([]string, 0, len(s.Status))
	for code, n := range s.Status {
		codes = append(codes, fmt.Sprintf("%s=%d", code, n))
	}
	sort.Strings(codes)
	fmt.Fprintln(w, "Status: "+strings.Join(codes, ", "))
	for _, section := range []struct {
		title string
		pairs []Pair
	}{{"Top routes", s.TopRoutes}, {"Top clients", s.TopClients}, {"Top server errors", s.TopServerErrors}} {
		if len(section.pairs) == 0 {
			continue
		}
		fmt.Fprintf(w, "\n%s\n", section.title)
		for _, p := range section.pairs {
			fmt.Fprintf(w, "  %7d  %s\n", p.Count, p.Name)
		}
	}
}

func run(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("logstats", flag.ContinueOnError)
	fs.SetOutput(stderr)
	n := fs.Int("top", 10, "how many routes, clients, and errors to list")
	output := fs.String("output", "text", "text or json")
	maxErrorRatio := fs.Float64("max-error-ratio", -1, "exit 1 if the 5xx ratio is higher (off by default)")
	if err := fs.Parse(args); err != nil {
		return 2
	}

	stats := NewStats()
	if fs.NArg() == 0 {
		if err := analyze(stdin, stats); err != nil {
			fmt.Fprintln(stderr, "logstats:", err)
			return 2
		}
	}
	for _, path := range fs.Args() {
		if err := analyzeFile(path, stats); err != nil {
			fmt.Fprintln(stderr, "logstats:", err)
			return 2
		}
	}

	summary := stats.Summary(*n)
	if *output == "json" {
		enc := json.NewEncoder(stdout)
		enc.SetIndent("", "  ")
		if err := enc.Encode(summary); err != nil {
			fmt.Fprintln(stderr, "logstats:", err)
			return 2
		}
	} else {
		renderText(stdout, summary)
	}
	if *maxErrorRatio >= 0 && stats.ErrorRatio() > *maxErrorRatio {
		return 1
	}
	return 0
}

func main() {
	os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr))
}
