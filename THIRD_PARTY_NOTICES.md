# Third-party notices

TypeAny's own source code is licensed under [AGPL-3.0](LICENSE). Release builds also bundle the
components below, each under its own license. The rime-ice data is GPL-3.0 and is not covered by
TypeAny's commercial license.

## Downloaded and bundled at build time

| Component | Used for | License |
|---|---|---|
| [rime-ice 雾凇拼音](https://github.com/iDvel/rime-ice) | Pinyin schema, dictionaries, lua scripts, emoji data (`scripts/build-rime-data.sh`, pinned revision) | GPL-3.0 |
| [librime-predict data](https://github.com/rime/librime-predict) | Next-word suggestions corpus, converted to Simplified Chinese (`scripts/build-predict-data.sh`) | BSD-3-Clause |
| [OpenCC](https://github.com/BYVoid/OpenCC) data | Simplified ↔ Traditional conversion | Apache-2.0 |

## Libraries bundled into the app (`scripts/bundle-libs.sh`)

| Library | License |
|---|---|
| [librime](https://github.com/rime/librime) | BSD-3-Clause |
| [librime-lua](https://github.com/hchunhui/librime-lua) | BSD-3-Clause |
| [librime-predict](https://github.com/rime/librime-predict) | BSD-3-Clause |
| [librime-octagram](https://github.com/lotem/librime-octagram) | BSD-3-Clause |
| [librime-proto](https://github.com/lotem/librime-proto) | BSD-3-Clause |
| [OpenCC](https://github.com/BYVoid/OpenCC) | Apache-2.0 |
| [Lua](https://www.lua.org) | MIT |
| [glog](https://github.com/google/glog) · [gflags](https://github.com/gflags/gflags) | BSD-3-Clause |
| [LevelDB](https://github.com/google/leveldb) · [Snappy](https://github.com/google/snappy) | BSD-3-Clause |
| [marisa-trie](https://github.com/s-yata/marisa-trie) | BSD-2-Clause or LGPL-2.1+ |
| [yaml-cpp](https://github.com/jbeder/yaml-cpp) | MIT |
| [Cap'n Proto](https://github.com/capnproto/capnproto) (libkj, libcapnp) | MIT |

Full license texts are available in each project's repository. The rime-ice license is also
shipped inside the app at `Contents/SharedSupport/rime-data/LICENSE`.
