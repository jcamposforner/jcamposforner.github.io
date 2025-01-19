JEKYLL=bundle exec jekyll

.PHONY: serve clean build

# Start development server
serve:
	$(JEKYLL) s

# Clean files
clean:
	$(JEKYLL) clean

# Build production
build:
	$(JEKYLL) build
