// Command tag-audit lists AWS resources missing required tags.
//
//	tag-audit -require Owner -require Environment
//	tag-audit -require Owner -type ec2:instance -type s3:bucket -output csv > untagged.csv
//	tag-audit -profile prod -region eu-west-1 -require CostCenter
//
// It uses the Resource Groups Tagging API, which lists taggable resources
// across services in one paginated call, and exits 1 if any resource is
// missing a tag. Credentials come from the default chain (environment, SSO
// profile, instance or pod role); none are stored here.
//
// The Tagging API returns resources that have, or have had, tags. A resource
// that was never tagged may not appear; AWS Config's required-tags rule
// covers that case.
package main

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	rgt "github.com/aws/aws-sdk-go-v2/service/resourcegroupstaggingapi"
)

// Finding is one resource missing one or more required tags.
type Finding struct {
	ARN     string   `json:"arn"`
	Service string   `json:"service"`
	Missing []string `json:"missing"`
}

// Audit pages through every resource (of the given types, if any) and returns
// those missing a required tag. The client is an interface so tests can fake it.
func Audit(ctx context.Context, client rgt.GetResourcesAPIClient, required, types []string) ([]Finding, error) {
	findings := []Finding{}
	pages := rgt.NewGetResourcesPaginator(client, &rgt.GetResourcesInput{ResourceTypeFilters: types})
	for pages.HasMorePages() {
		page, err := pages.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("listing resources: %w", err)
		}
		for _, m := range page.ResourceTagMappingList {
			tags := map[string]string{}
			for _, t := range m.Tags {
				tags[aws.ToString(t.Key)] = aws.ToString(t.Value)
			}
			var missing []string
			for _, key := range required {
				// An empty value counts as missing: "Owner=" is no owner.
				if strings.TrimSpace(tags[key]) == "" {
					missing = append(missing, key)
				}
			}
			if len(missing) > 0 {
				arn := aws.ToString(m.ResourceARN)
				service := ""
				if parts := strings.SplitN(arn, ":", 4); len(parts) > 2 {
					service = parts[2] // arn:partition:service:region:account:resource
				}
				findings = append(findings, Finding{ARN: arn, Service: service, Missing: missing})
			}
		}
	}
	return findings, nil
}

// stringList is a flag that can be repeated.
type stringList []string

func (s *stringList) String() string     { return strings.Join(*s, ",") }
func (s *stringList) Set(v string) error { *s = append(*s, v); return nil }

func render(w io.Writer, findings []Finding, output string) error {
	switch output {
	case "json":
		enc := json.NewEncoder(w)
		enc.SetIndent("", "  ")
		return enc.Encode(findings)
	case "csv":
		cw := csv.NewWriter(w)
		_ = cw.Write([]string{"arn", "service", "missing"})
		for _, f := range findings {
			_ = cw.Write([]string{f.ARN, f.Service, strings.Join(f.Missing, ";")})
		}
		cw.Flush()
		return cw.Error()
	default:
		for _, f := range findings {
			fmt.Fprintf(w, "%-16s %s  missing: %s\n", f.Service, f.ARN, strings.Join(f.Missing, ", "))
		}
		return nil
	}
}

func run(ctx context.Context, args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet("tag-audit", flag.ContinueOnError)
	fs.SetOutput(stderr)
	var required, types stringList
	fs.Var(&required, "require", "a tag every resource must have (repeatable)")
	fs.Var(&types, "type", "only these resource types, e.g. ec2:instance (repeatable)")
	profile := fs.String("profile", "", "shared config profile")
	region := fs.String("region", "", "AWS region")
	output := fs.String("output", "text", "text, json, or csv")
	if err := fs.Parse(args); err != nil {
		return 2
	}
	if len(required) == 0 {
		fmt.Fprintln(stderr, "tag-audit: give at least one -require KEY")
		return 2
	}

	var opts []func(*config.LoadOptions) error
	if *profile != "" {
		opts = append(opts, config.WithSharedConfigProfile(*profile))
	}
	if *region != "" {
		opts = append(opts, config.WithRegion(*region))
	}
	cfg, err := config.LoadDefaultConfig(ctx, opts...)
	if err != nil {
		fmt.Fprintln(stderr, "tag-audit:", err)
		return 2
	}

	findings, err := Audit(ctx, rgt.NewFromConfig(cfg), required, types)
	if err != nil {
		fmt.Fprintln(stderr, "tag-audit:", err)
		return 2
	}
	if err := render(stdout, findings, *output); err != nil {
		fmt.Fprintln(stderr, "tag-audit:", err)
		return 2
	}
	if *output == "text" {
		fmt.Fprintf(stderr, "%d resource(s) missing required tags\n", len(findings))
	}
	if len(findings) > 0 {
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
