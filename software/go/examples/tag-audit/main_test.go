package main

import (
	"bytes"
	"context"
	"slices"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	rgt "github.com/aws/aws-sdk-go-v2/service/resourcegroupstaggingapi"
	"github.com/aws/aws-sdk-go-v2/service/resourcegroupstaggingapi/types"
)

// fakeTagging serves two pages of resources, the way the real API paginates.
type fakeTagging struct {
	calls   int
	filters []string
}

func mapping(arn string, tags map[string]string) types.ResourceTagMapping {
	m := types.ResourceTagMapping{ResourceARN: aws.String(arn)}
	for k, v := range tags {
		m.Tags = append(m.Tags, types.Tag{Key: aws.String(k), Value: aws.String(v)})
	}
	return m
}

func (f *fakeTagging) GetResources(_ context.Context, in *rgt.GetResourcesInput, _ ...func(*rgt.Options)) (*rgt.GetResourcesOutput, error) {
	f.calls++
	f.filters = in.ResourceTypeFilters
	if aws.ToString(in.PaginationToken) == "" {
		return &rgt.GetResourcesOutput{
			PaginationToken: aws.String("page-2"),
			ResourceTagMappingList: []types.ResourceTagMapping{
				mapping("arn:aws:s3:::tagged", map[string]string{"Owner": "platform", "Environment": "dev"}),
				mapping("arn:aws:s3:::no-env", map[string]string{"Owner": "platform"}),
			},
		}, nil
	}
	return &rgt.GetResourcesOutput{
		PaginationToken: aws.String(""), // an empty token means the last page
		ResourceTagMappingList: []types.ResourceTagMapping{
			mapping("arn:aws:ec2:us-east-1:111122223333:instance/i-0abc", map[string]string{"Owner": " "}),
		},
	}, nil
}

func TestAuditFollowsPagesAndFindsGaps(t *testing.T) {
	client := &fakeTagging{}
	findings, err := Audit(t.Context(), client, []string{"Owner", "Environment"}, []string{"s3:bucket", "ec2:instance"})
	if err != nil {
		t.Fatal(err)
	}
	if client.calls != 2 {
		t.Errorf("GetResources called %d times, want 2 (one per page)", client.calls)
	}
	if !slices.Equal(client.filters, []string{"s3:bucket", "ec2:instance"}) {
		t.Errorf("filters = %v", client.filters)
	}
	want := []Finding{
		{ARN: "arn:aws:s3:::no-env", Service: "s3", Missing: []string{"Environment"}},
		{ARN: "arn:aws:ec2:us-east-1:111122223333:instance/i-0abc", Service: "ec2", Missing: []string{"Owner", "Environment"}},
	}
	if len(findings) != len(want) {
		t.Fatalf("findings = %+v", findings)
	}
	for i := range want {
		if findings[i].ARN != want[i].ARN || findings[i].Service != want[i].Service ||
			!slices.Equal(findings[i].Missing, want[i].Missing) {
			t.Errorf("finding %d = %+v, want %+v", i, findings[i], want[i])
		}
	}
}

func TestRenderCSV(t *testing.T) {
	var buf bytes.Buffer
	err := render(&buf, []Finding{{ARN: "arn:aws:s3:::b", Service: "s3", Missing: []string{"Owner", "Environment"}}}, "csv")
	if err != nil {
		t.Fatal(err)
	}
	if got := buf.String(); got != "arn,service,missing\narn:aws:s3:::b,s3,Owner;Environment\n" {
		t.Errorf("csv = %q", got)
	}
}

func TestRenderJSONEmptyIsArray(t *testing.T) {
	var buf bytes.Buffer
	if err := render(&buf, []Finding{}, "json"); err != nil {
		t.Fatal(err)
	}
	if strings.TrimSpace(buf.String()) != "[]" {
		t.Errorf("json = %q, want []", buf.String())
	}
}

func TestRequiresATag(t *testing.T) {
	var out, errOut bytes.Buffer
	if code := run(t.Context(), nil, &out, &errOut); code != 2 {
		t.Errorf("exit %d, want 2 without -require", code)
	}
}
