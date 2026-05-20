# Contributing to Skill-Hub

Thank you for your interest in contributing!

## Ways to Contribute

### 1. Submit a Skill

Share a skill that others can use:

1. Fork this repository
2. Create your skill in `skills/<name>/SKILL.md`
3. Ensure it passes `skill-sync check <name>` with no block-level issues
4. Ensure it passes `skill-sync check <name> --security` with no critical issues
5. Submit a pull request

### 2. Report Issues

File bugs or feature requests via GitHub Issues.

### 3. Add an Adapter

If you use a framework not yet supported:

1. Create `adapters/<framework-name>.sh`
2. Follow the [adapter guide](docs/adapter-guide.md)
3. Test with an existing skill
4. Submit a pull request

## Skill Quality Requirements

All submitted skills must:

- Pass `skill-sync check` (no block-level issues)
- Pass `skill-sync check --security` (no critical issues)
- Include proper frontmatter with `name`, `version`, `description`, `depends`
- Use `$HOME` instead of absolute paths
- Use environment variables instead of hardcoded secrets
- Declare all required environment variables in `depends.env`
- Use FRAMEWORK conditional sections for framework-specific behavior

## Development

```bash
# Clone
git clone https://github.com/user/skill-hub.git
cd skill-hub

# Run checks
./bin/skill-sync check examples/hello-world
./bin/skill-sync doctor

# Test install (in a safe directory)
./install.sh --non-interactive --frameworks "cc:$HOME/.claude/skills"
```

## Code of Conduct

Be respectful. Be constructive. Be inclusive.
