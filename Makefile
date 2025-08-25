TARGET=au.org.nectar.JupyterLab

.PHONY: all build clean upload public

all: clean package.zip

build: package.zip

clean:
	rm -rf package.zip

upload: package.zip
	murano package-import -c "Big Data" --package-version 1.0 --exists-action u package.zip

public:
	@echo "Searching for $(TARGET) package ID..."
	@package_id=$$(murano package-list --fqn $(TARGET) | grep $(TARGET) | awk '{print $$2}'); \
	echo "Found ID: $$package_id"; \
	murano package-update --is-public true $$package_id

package.zip:
	cd $(TARGET) && zip -r ../$@ *
