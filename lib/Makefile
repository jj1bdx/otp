#
# %CopyrightBegin%
#
# SPDX-License-Identifier: Apache-2.0
#
# Copyright Ericsson AB 1996-2025. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# %CopyrightEnd%

include $(ERL_TOP)/make/target.mk
include $(ERL_TOP)/make/$(TARGET)/otp.mk


# These have to be built first
ERTS_APPLICATIONS = stdlib sasl kernel compiler

# Then these have to be build
ifdef TINY_BUILD
ERLANG_APPLICATIONS = parsetools
else
ERLANG_APPLICATIONS = tools common_test runtime_tools inets parsetools
endif

# These are only build if -a is given to otp_build or make is used directly
ALL_ERLANG_APPLICATIONS = xmerl edoc snmp erl_interface \
		  asn1 jinterface \
	          wx debugger reltool \
	          mnesia crypto os_mon syntax_tools \
	          public_key ssl observer odbc diameter \
	          et megaco \
		  eunit ssh eldap dialyzer ftp tftp


ifdef BUILD_ALL
  ERLANG_APPLICATIONS += $(ALL_ERLANG_APPLICATIONS)

# We use whildcard */ to figure out if there are any other applications
# in here.
  EXPECTED_APPLICATIONS := $(ERTS_APPLICATIONS) $(ERLANG_APPLICATIONS) \
	autom4te.cache
  EXTRA_APPLICATIONS += $(filter-out $(EXPECTED_APPLICATIONS),\
				$(subst /,,$(wildcard */)))
endif

ifdef BUILD_STATIC_LIBS
  SUB_DIRECTORIES = asn1 crypto
else
  ifdef BOOTSTRAP
    SUB_DIRECTORIES = $(BOOTSTRAP)
  else # Not bootstrap build
    SUB_DIRECTORIES = $(ERTS_APPLICATIONS) \
		      $(ERLANG_APPLICATIONS) \
		      $(EXTRA_APPLICATIONS)
  endif
endif

# Any applications listed in SKIP-APPLICATIONS should be skipped
SKIP_FILE := $(wildcard SKIP-APPLICATIONS)
SKIP_APPLICATIONS := $(if $(SKIP_FILE),$(shell cat $(SKIP_FILE)))
SUB_DIRECTORIES := $(filter-out $(SKIP_APPLICATIONS),$(SUB_DIRECTORIES))

# ----------------------------------------------------------------------
include $(ERL_TOP)/make/otp_subdir.mk
