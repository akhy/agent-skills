SKILLS := $(shell find . -maxdepth 2 -name 'SKILL.md' | xargs -I{} dirname {} | sed 's|^\./||' | sort)

.PHONY: validate

validate: ## Validate all skill directories
	@for dir in $(SKILLS); do \
		npx skills-ref validate $$dir || exit 1; \
	done
