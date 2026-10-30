DOCKER_IMG_VERSION="1.0"
DOCKER_IMG_NAME="devutils/ubuntu"
DOCKER_IMG=$(DOCKER_IMG_NAME):$(DOCKER_IMG_VERSION)

clean:
	docker image rm $(DOCKER_IMG)

build-docker: 
	docker build --rm=true -f docker/Dockerfile -t $(DOCKER_IMG) docker/

build-sd:
	docker run --rm=true --privileged 				\
		   -v /lib/modules:/lib/modules -v /boot:/boot 		\
		   -v $(PWD):$(PWD) -w $(PWD) 				\
		   -it $(DOCKER_IMG)  $(PWD)/mk_ubuntu_sd.sh
