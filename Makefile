TARGET=au.org.nectar.JupyterNotebook
.PHONY: $(TARGET).zip

all: update-image-id $(TARGET).zip

build: $(TARGET).zip

clean:
	rm -rf $(TARGET).zip

upload: $(TARGET).zip
	murano package-import -c "Big Data" --package-version 1.0 --exists-action u $(TARGET).zip

public:
	@echo "Searching for $(TARGET) package ID..."
	@package_id=$$(murano package-list --fqn $(TARGET) | grep $(TARGET) | awk '{print $$2}'); \
	echo "Found ID: $$package_id"; \
	murano package-update --is-public true $$package_id

update-image-id:
	@echo "Searching for latest image of NeCTAR Jupyter Notebook (Ubuntu 18.04 LTS Bionic)..."
	@image_id=$$(openstack image list --limit 100 --long -f value -c ID -c Project --property "name=NeCTAR Jupyter Notebook (Ubuntu 18.04 LTS Bionic)" --sort created_at | tail -n1 | cut -d" " -f1); \
	if [ -z "$$image_id" ]; then \
		echo "Image ID not found"; exit 1; \
	fi; \
    echo "Found ID: $$image_id"; \
    sed -i "s/image:.*/image: $$image_id/g" $(TARGET)/UI/ui.yaml

$(TARGET).zip:
	rm -f $@; cd $(TARGET); zip ../$@ -r *; cd ..
