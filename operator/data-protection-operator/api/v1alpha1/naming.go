package v1alpha1

import (
	"crypto/sha1"
	"encoding/hex"
	"strings"
	"unicode"
)

const (
	maxCronJobNameLength = 52
	maxJobNameLength     = 63
	maxLabelValueLength  = 63
)

func BuildCronJobName(parts ...string) string {
	return buildDNSLabelName(maxCronJobNameLength, parts...)
}

func BuildJobName(parts ...string) string {
	return buildDNSLabelName(maxJobNameLength, parts...)
}

func BuildLabelValue(parts ...string) string {
	return buildDNSLabelName(maxLabelValueLength, parts...)
}

func sanitizeName(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return "dp"
	}

	var builder strings.Builder
	lastHyphen := false
	for _, r := range value {
		switch {
		case unicode.IsLower(r) || unicode.IsDigit(r):
			builder.WriteRune(r)
			lastHyphen = false
		case r == '-' || r == '_' || r == '.' || r == '/' || unicode.IsSpace(r):
			if !lastHyphen && builder.Len() > 0 {
				builder.WriteByte('-')
				lastHyphen = true
			}
		default:
			if !lastHyphen && builder.Len() > 0 {
				builder.WriteByte('-')
				lastHyphen = true
			}
		}
	}

	result := strings.Trim(builder.String(), "-")
	if result == "" {
		return "dp"
	}
	return result
}

func buildDNSLabelName(maxLength int, parts ...string) string {
	sanitized := make([]string, 0, len(parts))
	for _, part := range parts {
		part = sanitizeName(part)
		if part != "" {
			sanitized = append(sanitized, part)
		}
	}
	if len(sanitized) == 0 {
		sanitized = []string{"dp"}
	}

	name := strings.Join(sanitized, "-")
	if len(name) <= maxLength {
		return name
	}

	hash := shortHash(name)
	prefixLength := maxLength - len(hash) - 1
	if prefixLength < 1 {
		if maxLength <= len(hash) {
			return hash[:maxLength]
		}
		return hash[:maxLength-1]
	}

	prefix := strings.Trim(name[:prefixLength], "-")
	if prefix == "" {
		prefix = "dp"
	}
	name = prefix + "-" + hash
	if len(name) <= maxLength {
		return name
	}
	return strings.Trim(name[:maxLength], "-")
}

func shortHash(value string) string {
	sum := sha1.Sum([]byte(value))
	return hex.EncodeToString(sum[:])[:8]
}
