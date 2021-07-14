
SONIC_ONOS_DRIVER_DIR := ./sonic-onos-driver

TRELLIS_DIR := $(shell pwd)/trellis-control
MAVEN_IMG := maven:3.6.3-jdk-11-slim
CURR_DIR_SHA := $(shell echo -n "$(CURR_DIR)" | shasum | cut -c1-7)

mvn_build_container_name := mvn-build-${CURR_DIR_SHA}


deps: pull build ./tmp onos-tools
	git submodule update --init
	cd ${SONIC_ONOS_DRIVER_DIR} && make deps

onos-tools:
	curl -sS https://repo1.maven.org/maven2/org/onosproject/onos-releases/2.5.0/onos-admin-2.5.0.tar.gz --output onos-admin-2.5.0.tar.gz
	tar xf onos-admin-2.5.0.tar.gz
	rm onos-admin-2.5.0.tar.gz
	mv onos-admin-2.5.0 onos-tools

./tmp:
	@mkdir -p ./tmp

pull:
	docker-compose pull

build:
	docker-compose build --pull

build-apps: build-trellis
	cd sonic-onos-driver && make build

build-trellis: _create_mvn_container _mvn_package
	$(info *** ONOS app .oar package created succesfully)
	@ls -1 ${TRELLIS_DIR}/app/target/*.oar

# Reuse the same container to persist mvn repo cache.
_create_mvn_container:
	@if ! docker container ls -a --format '{{.Names}}' | grep -q ${mvn_build_container_name} ; then \
		docker create -v ${TRELLIS_DIR}:/mvn-src -w /mvn-src  --user "$(id -u):$(id -g)" --name ${mvn_build_container_name} ${MAVEN_IMG} mvn clean install; \
	fi

_mvn_package:
	$(info *** Building TRELLIS-CONTROL app...)
	@mkdir -p ${TRELLIS_DIR}/target
	@docker start -a -i ${mvn_build_container_name}

local-build-trellis:
	cd trellis-control && mvn clean install

start:
	docker-compose up -d

stop:
	docker-compose down

push-netcfg:
	onos-tools/onos-netcfg localhost config-demo.json

push-apps: push-trellis
	cd sonic-onos-driver && make push_driver
	cd sonic-onos-driver && make push_pipeliner

push-trellis: trellis-control/app/target/segmentrouting-app-3.0.1-SNAPSHOT.oar onos-tools
	onos-tools/onos-app localhost reinstall! trellis-control/app/target/segmentrouting-app-3.0.1-SNAPSHOT.oar

zebra-cli:
	docker-compose exec quagga telnet localhost 2601

onos-log:
	docker-compose logs -f onos

onos-cli:
	ssh -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -o LogLevel=ERROR -p 8101 onos@localhost

onos-ui:
	open http://localhost:8181/onos/ui

clean:
	-docker-compose down -t0 --remove-orphans
	-cd sonic-onos-driver && make clean
	-rm -rf /tmp
	-rm -r onos-tools
	-rm -r trellis-control/target trellis-control/*/target
