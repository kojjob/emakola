# Contributing to Emakola

## Getting Started
1. Fork the repo and create a feature branch
2. Follow conventions in `AGENTS.md`
3. Write tests first (TDD)
4. Run full test suite before submitting PR

## Branch Naming
```
feature/{description}     — New functionality
fix/{description}         — Bug fixes
hotfix/{description}      — Production fixes
chore/{description}       — Maintenance
```

## Commit Messages
```
feat(catalog): add product variant support
fix(payments): handle MTN MoMo timeout
test(orders): add concurrent checkout test
refactor(auth): extract session management
docs(api): update webhook documentation
chore(deps): update ash to 3.16
perf(storefront): optimize product listing query
```

## Pull Request Process
1. The full project gate passes (`mix precommit`)
2. New behaviour has outcome-focused tests and the configured coverage floor is maintained
3. Documentation is updated when configuration or behaviour changes
4. One cohesive feature/fix per PR
5. Request review from at least one maintainer

## Code Review Checklist
- [ ] Tests pass and coverage maintained
- [ ] No N+1 queries introduced
- [ ] Multi-tenant isolation verified
- [ ] No PII in logs
- [ ] Payment amounts validated server-side
- [ ] Ash authorization policies in place
- [ ] LiveView handles disconnection gracefully
- [ ] Mobile-responsive (tested at 375px)
- [ ] All money in minor units (pesewas/kobo), never floats

## Development Principles
- TDD always — red, green, refactor
- Ash resources for data, services for complex logic
- WhatsApp > SMS > Email for notifications
- Mobile-first design
- Measure, don't assume
