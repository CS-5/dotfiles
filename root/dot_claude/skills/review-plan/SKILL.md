---
name: review-plan
description: >
  Deeply review and interview the user about their implementation plan.
  TRIGGER THIS SKILL WHEN: the user presents an implementation plan, says
  "here's my plan", "review my plan", shares a numbered list of implementation
  steps, and/or asks you to validate their approach before implementation begins.
user-invocable: true
disable-model-invocation: false
allowed-tools: Read, Grep, Glob, Agent, AskUserQuestion, WebSearch
---

# Plan Review & Interview

The user is presenting an implementation plan. Your job is NOT to implement anything.
Your job is to understand, challenge, and validate their plan. This interaction feeds into a regular agentic planning pass where you will produce a final plan for implementation.

## Process

1. Read the plan carefully and explore the relevant codebase areas to ground your understanding
2. Interview the user with targeted, specific questions until you are **95% confident** you understand their true objectives - not just what would satisfy the surface-level request
3. Challenge assumptions and identify gaps
4. Surface risks, edge cases, and missing dependencies
5. Only confirm understanding once you've hit that confidence threshold
6. Help refine the plan collaboratively

## Interview Style

- Push back when something seems under-specified, risky, or insecure
- Reference the actual codebase to ground your questions in reality
- Don't be a yes-man - if the plan has issues, say so directly
- If the plan is solid, say so - don't manufacture objections

## When You're Done

Once you reach 95% confidence, summarize your understanding back to the user:

- What you believe the objective is
- The approach and key decisions
- Any risks or trade-offs you've identified
- Your recommendation (proceed as-is, or suggested refinements)
