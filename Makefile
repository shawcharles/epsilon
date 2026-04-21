JULIA ?= julia
RUNIC ?= $(JULIA) --project=@runic -m Runic

.PHONY: instantiate test format format-check docs quality

instantiate:
	$(JULIA) --project=. -e 'using Pkg; Pkg.instantiate()'

test:
	$(JULIA) --project=. -e 'using Pkg; Pkg.test()'

quality:
	$(JULIA) --project=. -e 'using Pkg; Pkg.test()'

format:
	$(RUNIC) --inplace src/ test/ docs/

format-check:
	$(RUNIC) --check --diff src/ test/ docs/

docs:
	$(JULIA) --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
	$(JULIA) --project=docs docs/make.jl
