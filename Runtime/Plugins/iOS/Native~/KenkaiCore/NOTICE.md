# Bundled iOS Core SDK notice

This directory redistributes the Causal Foundry/Kenkai iOS Core SDK version `1.0.10` from
`https://github.com/CausalFoundry/ios-sdk`, tag and commit
`fb1390d9dff7bc054eb59b6df89a6778ad20ed45`.

The Causal Foundry/Kenkai source is licensed under the Apache License, Version 2.0. A copy of that
license is included as `LICENSE.md` at the root of the Unity package.

Except for the source changes described below, the redistributed Swift sources and
`MMKV.xcframework` are byte-for-byte copies of the `1.0.10` release. The local package is modified
to:

- expose only the `KenkaiSDKCore` product and its MMKV dependency;
- omit non-Core products and test targets; and
- declare iOS 13 instead of iOS 12 because this Core release uses APIs that require iOS 13;
- gate automatic action listening in `CFSetup.swift` when Core starts paused; and
- add `CoreConstants.setUnityRuntimePaused`, which stops or resumes that listener when the Unity
  wrapper applies a runtime consent change; and
- retain and remove `CFActionListener` lifecycle-observer tokens, and guard automatic polling and
  display work while that runtime pause is active; and
- extend `CFNotificationController` with explicit authorization support plus notification-delegate
  installation and forwarding for Unity host applications.

The upstream `Utility/Extensions/CodableExtension.swift` is not redistributed. It references and
substantially incorporates code from a GPL-3.0 project, which is inconsistent with this package's
Apache-2.0 distribution. This local package replaces only the Codable dictionary and catalog/event
flattening surface used by Core with the independently authored
`CausalFoundryUnityCodableSupport.swift`. The replacement is licensed under Apache-2.0 as part of
the Unity package and uses only Apple Foundation APIs.

## MMKV

`MMKV.xcframework` is distributed by the upstream Causal Foundry/Kenkai release and contains MMKV:

The embedded framework Info.plists identify MMKV `1.3.4`. The upstream Causal Foundry `1.0.10`
build script does not pin an MMKV source revision, so this wrapper records the exact shipped binary
SHA-256 values for reproducibility:

- iOS arm64: `54869212a93ae2b7f59ab2a79b19d25b1b54ee1a94ab2010a5bc3915e9ef5917`
- iOS simulator arm64/x86_64:
  `a21df13450e4e58403ac8121b6e87d6b7fd5eb582cc6faf748ee8be8965390e9`

Copyright (C) 2018 THL A29 Limited, a Tencent company.

Redistribution and use in source and binary forms, with or without modification, are permitted
provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions
   and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of
   conditions and the following disclaimer in the documentation and/or other materials provided
   with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to
   endorse or promote products derived from this software without specific prior written
   permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Reachability.swift

The bundled Core sources include `Reachability.swift`:

Copyright (c) 2014, Ashley Mills. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted
provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions
   and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of
   conditions and the following disclaimer in the documentation and/or other materials provided
   with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
