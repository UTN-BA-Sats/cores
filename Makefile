define run_in_container
	docker run -it --rm \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		-v /var/run/dbus:/var/run/dbus \
		--network host \
		-e DISPLAY=$(DISPLAY) \
		${EXTRA_ARGS} \
		-v $(PWD):/code -w /code \
		$(DOCKER_IMAGE_NAME) $(1)
endef

DOCKER_IMAGE_NAME = hdlcores:latest


help:  ## Shows the available targets
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'


clean:  ## Clean building files
	@$(call run_in_container, find . \
		-name 'results.xml' -o \
		-name 'sim.vpp' -o \
		-name 'waveform.vcd' \
		-exec rm -r {} \;)


build.docker:  ## Deletes docker image and Builds a new one used for development
	-docker image rm ${DOCKER_IMAGE_NAME}
	docker build --no-cache --tag ${DOCKER_IMAGE_NAME} -f Dockerfile .


dockershell:  ## Run the development container
	@$(call run_in_container, bash)


test:  ## Run all tests or the ones for specific module setting DUT variable
	@$(call run_in_container, ./run_cocotb_tests.sh ${DUT})


test.waves:  ## Run gtkwave with last test waves from DUT variable
	@[ "${DUT}" ] || ( echo "Usage:    DUT=<module> make waves"; exit 1 )
	@$(call run_in_container, ./run_cocotb_tests.sh ${DUT} --waves)


flake8:  ## Run flake8 code quality check
	$(eval PYTHON_FILES := $(shell find . -name "*.py"))
	@$(call run_in_container, flake8 ${PYTHON_FILES} --max-line-length=120)


verible:  ## Run verible-verilog-lint code quality check
	$(eval VHDL_FILES := $(shell find rtl/ -name "*.v"))
	@$(call run_in_container, verible-verilog-lint ${VHDL_FILES})


quality: flake8 verible  ## Run all quality check


.DEFAULT_GOAL := help
.PHONY: help clean build-docker dockershell test flake8 verible quality
