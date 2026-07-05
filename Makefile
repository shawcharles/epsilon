JULIA ?= julia
RUNIC ?= $(JULIA) --project=@runic -m Runic
export JULIA_PKG_SERVER_REGISTRY_PREFERENCE ?= eager

.PHONY: instantiate test test-full test-model test-optimization test-validation \
	format format-check format-check-touched docs check check-optimization \
	check-validation check-full check-release quality parity-check

instantiate:
	$(JULIA) --project=. -e 'using Pkg; Pkg.instantiate()'

test: test-full

test-full:
	$(JULIA) --project=. -e 'using Pkg; Pkg.test()'

test-model:
	$(JULIA) --project=. -e 'using Pkg; Pkg.test(; test_args=["model"])'

test-optimization:
	$(JULIA) --project=. -e 'using Pkg; Pkg.test(; test_args=["optimization"])'

test-validation:
	$(JULIA) --project=. -e 'using Pkg; Pkg.test(; test_args=["validation"])'

format:
	$(RUNIC) --inplace src/ test/ docs/

format-check:
	$(RUNIC) --check --diff src/ test/ docs/

format-check-touched:
	@files="$$( \
		{ git diff --name-only -- '*.jl'; \
		  git diff --name-only --cached -- '*.jl'; \
		  git ls-files --others --exclude-standard -- '*.jl'; } | sort -u \
	)"; \
	if [ -z "$$files" ]; then \
		echo "No touched Julia files to format-check."; \
	else \
		$(RUNIC) --check --diff $$files; \
	fi

docs:
	$(JULIA) --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
	$(JULIA) --project=docs docs/make.jl

check: format-check-touched test-model

check-optimization: format-check-touched test-optimization

check-validation: format-check-touched test-validation

check-full: format-check-touched test-full docs

check-release: format-check test-full docs

quality: check-full

parity-check: test-validation
