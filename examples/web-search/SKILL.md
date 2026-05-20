---
name: web-search
version: 1.0.0
description: Web search skill with portable configuration
depends:
  tools: [curl]
  env:
    SEARCH_API_KEY:
      required: true
      description: "API key for search service"
    SEARCH_BASE_URL:
      required: false
      default: "https://api.search.example.com"
  os: [macos, linux]
  frameworks: [cc, cx, hermes]
tags: [search, web, api]
---

# Web Search

Search the web using a configurable search API.

## Configuration

This skill requires the following environment variables:

- `SEARCH_API_KEY` (required): Your search API key
- `SEARCH_BASE_URL` (optional, default: `https://api.search.example.com`)

## Usage

When the user asks to search for something:

1. Extract the search query
2. Call the search API using the configured endpoint
3. Format and present the results

## API Call

```bash
curl -s -H "Authorization: Bearer $SEARCH_API_KEY" \
  "${SEARCH_BASE_URL}/search?q=$(python3 -c 'import urllib.parse; print(urllib.parse.quote("$QUERY"))')"
```

## Framework-specific notes

<!-- FRAMEWORK:cc -->
Use the `Skill` tool to invoke: `Skill(skill="web-search")`
<!-- /FRAMEWORK:cc -->

<!-- FRAMEWORK:hermes -->
Use `activate_skill(name="web-search")` to load.
<!-- /FRAMEWORK:hermes -->

<!-- FRAMEWORK:generic -->
Read this file and inject its content as instructions.
<!-- /FRAMEWORK:generic -->
