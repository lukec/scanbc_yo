IMAGE_NAME="quay.io/lukec/scanbc-yo"
CONTAINER_NAME="scanbc-yo"

run:
	sudo docker stop $(CONTAINER_NAME) || true
	sudo docker rm -v $(CONTAINER_NAME) || true
	sudo docker pull $(IMAGE_NAME)
	sudo docker run -d -v `pwd`/etc:/opt/scanbc_yo/etc --name $(CONTAINER_NAME) $(IMAGE_NAME)

.PHONY: image

