CXX ?= g++
BUILD ?= release
LINK ?= dynamic

TARGET_NAME := outrift

# platform detection
ifeq ($(OS),Windows_NT)
	PLATFORM := windows
	MD = if not exist "$(subst /,\,$(patsubst %/,%,$(1)))" mkdir "$(subst /,\,$(patsubst %/,%,$(1)))"
	RM = if exist "$(subst /,\,$(1))" del /Q /F "$(subst /,\,$(1))"
	RD = if exist "$(subst /,\,$(1))" rmdir /S /Q "$(subst /,\,$(1))"
	EXE_EXT := .exe
	SOURCES := $(shell powershell -NoProfile -Command "Get-ChildItem -Path 'src' -Recurse -Filter *.cpp | Resolve-Path -Relative | ForEach-Object { $$_ -replace '\\\\','/' -replace '^\./','' }")
else
	PLATFORM := posix
	MD = mkdir -p "$(1)"
	RM = rm -f "$(1)"
	RD = rm -rf "$(1)"
	EXE_EXT := .elf
	SOURCES := $(shell find src -type f -name "*.cpp")
endif

ROOT_DIR     := .
EXTERNAL_DIR := extern
CX_ENGINE_DIR := $(abspath $(EXTERNAL_DIR)/cx-engine)
CX_ENGINE_OUT := $(CX_ENGINE_DIR)/out/$(BUILD)-$(LINK)

BUILD_DIR  := build/$(BUILD)
OUT_DIR    := out/$(BUILD)-$(LINK)
TARGET     := $(OUT_DIR)/$(TARGET_NAME)$(EXE_EXT)

CXXSTD := -std=c++20
WARNINGS := -Wall
COMMON_CXXFLAGS := $(CXXSTD) $(WARNINGS)

ifeq ($(BUILD),debug)
	CXXFLAGS := $(COMMON_CXXFLAGS) -O0 -g -DDEBUG
else
	CXXFLAGS := $(COMMON_CXXFLAGS) -O3 -DNDEBUG
endif

export PKG_CONFIG_PATH := $(CX_ENGINE_OUT):$(PKG_CONFIG_PATH)

PC_VARS := --define-variable=prefix=$(CX_ENGINE_DIR) --define-variable=libdir=$(CX_ENGINE_OUT)
PC_CMD  := pkg-config $(PC_VARS) $(if $(filter static,$(LINK)),--static)

GET_CX_FLAGS = $(shell $(PC_CMD) --cflags cx-engine 2>/dev/null)
GET_CX_LIBS  = $(shell $(PC_CMD) --libs cx-engine 2>/dev/null)

INCLUDES := -I$(ROOT_DIR)/include
OBJECTS  := $(patsubst %.cpp,$(BUILD_DIR)/%.o,$(SOURCES))
DEPS     := $(OBJECTS:.o=.d)

# Map LINK to LIBTYPE for cx-engine
ifeq ($(LINK),dynamic)
	CX_LIBTYPE := shared
else
	CX_LIBTYPE := $(LINK)
endif

.PHONY: all clean dirs engine submodules

all: dirs engine $(TARGET)

dirs:
	@$(call MD,$(BUILD_DIR))
	@$(call MD,$(OUT_DIR))

engine:
	@$(MAKE) -C $(CX_ENGINE_DIR) BUILD=$(BUILD) LINK=$(LINK) LIBTYPE=$(CX_LIBTYPE)

submodules:
	git submodule update --init --remote --recursive

$(TARGET): $(OBJECTS)
	$(CXX) $(CXXFLAGS) -o $@ $(OBJECTS) $(LDFLAGS) $(GET_CX_LIBS)

$(BUILD_DIR)/%.o: %.cpp | engine
	@$(call MD,$(@D))
	$(CXX) $(CXXFLAGS) $(INCLUDES) $(GET_CX_FLAGS) -MMD -MP -c $< -o $@

-include $(DEPS)

clean:
	@$(call RD,build)
	@$(call RD,out)
	$(MAKE) -C $(CX_ENGINE_DIR) clean
