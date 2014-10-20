IMAGE_NAME="lukec/scanbc-yo"

image:
	sudo docker build -t $(IMAGE_NAME)

run:
	sudo docker run -v `pwd`/etc:/opt/scanbc_yo/etc --name scanbc-yo $(IMAGE_NAME)

.PHONY: image

