---
name: hello-world
version: 1.0.0
description: A minimal example skill
depends:
  tools: []
  env: []
  os: [macos, linux]
  frameworks: [cc, cx, hermes, any]
tags: [example, demo]
---

# Hello World

This is a minimal example skill that demonstrates the skill-hub format.

## What it does

When the user says "hello", respond with a friendly greeting.

## Instructions

1. Detect the user's greeting language
2. Respond in the same language
3. Add a fun fact about today's date

## Framework-specific notes

<!-- FRAMEWORK:cc -->
In Claude Code, this skill is loaded automatically from `~/.claude/skills/hello-world/`.
<!-- /FRAMEWORK:cc -->

<!-- FRAMEWORK:hermes -->
In Hermes, use `activate_skill(name="hello-world")` to load.
<!-- /FRAMEWORK:hermes -->

<!-- FRAMEWORK:generic -->
Load this skill file and use its content as system instructions.
<!-- /FRAMEWORK:generic -->
