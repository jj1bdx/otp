<!--
%CopyrightBegin%

SPDX-License-Identifier: Apache-2.0

Copyright Ericsson AB 2023-2025. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

%CopyrightEnd%
-->
# ASN.1

## Introduction

ASN.1 is a formal language for describing data structures to be exchanged
between distributed computer systems. The purpose of ASN.1 is to have a platform
and programming language independent notation to express types using a
standardized set of rules for the transformation of values of a defined type
into a stream of bytes. This stream of bytes can then be sent on any type of
communication channel. This way, two applications written in different
programming languages running on different computers, and with different
internal representation of data, can exchange instances of structured data
types.
