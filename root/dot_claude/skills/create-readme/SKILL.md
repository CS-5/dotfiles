---
name: create-readme
description: Create a directory/package specific readme file
argument-hint: <directory/path>
allowed-tools: Read, Glob, Grep, AskUserQuestion
disable-model-invocation: true
---

# Overview

Create a comprehensive README.md file in $ARGUMENTS that would be useful for humans or AI Agents when interacting with the codebase.

## Instructions

Directory/package: $ARGUMENTS

1. Review the overall structure of the repository and existing README.md files. DO NOT LOOK AT README FILES IN `node_modules` (at any level).
2. Look for distinct patterns, usage examples, existing documentation, and other helpful indicators in the directory in question.
3. Ask clarifying questions for patterns or areas you do not understand to ensure you have a solid foundation before producing the README.
4. Produce a comprehensive and clear README in the directory/package specified. The README should follow established patterns for readability and structure found elsewhere in the repository. It should be concise enough for AI agents to use without exhausting context windows and clear enough for humans to understand, especially when not familiar with that area of the codebase. Include best practices and usage examples if the README is for a specific code package or internal library.
5. Review the readme and the package again after creating it. Think carefully about the content and ensure it is accurate. Ask another round of clarifying questions if needed.
6. Provide a summary of the content to the user.
