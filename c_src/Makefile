ERL ?= erl
BASEDIR=$(CURDIR)
PRIVDIR=./priv

NIF_DIR=c_src
NIF_ENV=c_src/env.mk

NIF_SOURCES=$(NIF_DIR)/ucol.c
NIF_OBJS=$(NIF_DIR)/ucol.o
NIF_SO=$(PRIVDIR)/ucol.so

UNAME_SYS := $(shell uname -s)
ifeq ($(UNAME_SYS), Darwin)
	CC ?= cc
	CFLAGS ?= -O3 -std=c99 -arch x86_64 -Wall -Wmissing-prototypes
	LDFLAGS ?= -arch x86_64 -flat_namespace -undefined suppress
else ifeq ($(UNAME_SYS), FreeBSD)
	CC ?= cc
	CFLAGS ?= -O3 -std=c99 -finline-functions -Wall -Wmissing-prototypes
	CXXFLAGS ?= -O3 -finline-functions -Wall
else ifeq ($(UNAME_SYS), Linux)
	CC ?= gcc
	CFLAGS ?= -O3 -std=c99 -finline-functions -Wall -Wmissing-prototypes
	CXXFLAGS ?= -O3 -finline-functions -Wall
endif

CFLAGS += -fPIC -I$(ERTS_INCLUDE_DIR) -I$(ERL_INTERFACE_INCLUDE_DIR)
LDLIBS += -L$(ERL_INTERFACE_LIB_DIR) -lerl_interface -lei
LDFLAGS += -shared

ifeq ($(UNAME_SYS), Darwin)
	ICU_CFLAGS = -I$(BASEDIR)/c_src/platform/osx/icu
	ICU_LIBS = -lpthread -lm -licucore -lstdc++
else
	ICU_CFLAGS = $(shell pkg-config --cflags icu-uc icu-io)
	ICU_LIBS = $(shell pkg-config --libs icu-uc icu-io)
endif


all: $(NIF_ENV) $(NIF_SO)

clean:
	@rm -rf $(NIF_SO) $(NIF_OBJS)

distclean: clean
	@rm -rf $(NIF_ENV)

$(NIF_SO): $(NIF_OBJS)
	@mkdir -p $(PRIVDIR)
	$(CC) $(NIF_OBJS) $(LDFLAGS) $(LDLIBS) $(ICU_LIBS) -o $(NIF_SO)

%.o: %.c
	@$(CC) -c $(CFLAGS) $(CPPFLAGS) $(ICU_CFLAGS) $< -o $@

$(NIF_ENV):
	@$(ERL) -eval "file:write_file(\"$(NIF_ENV)\", \
		io_lib:format( \
		\"ERTS_INCLUDE_DIR ?= ~s/erts-~s/include/~n\" \
		\"ERL_INTERFACE_INCLUDE_DIR ?= ~s~n\" \
		\"ERL_INTERFACE_LIB_DIR ?= ~s~n\", \
		[code:root_dir(), erlang:system_info(version), \
		code:lib_dir(erl_interface, include), \
		code:lib_dir(erl_interface, lib)])), \
		halt()."

-include $(NIF_ENV)