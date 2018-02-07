# eos-afl container for fuzzing and stuff

## the idea
this container is set up to enable compiling xrootd and eos with afl-gcc and afl-g++
the above allows afl to intelligently fuzz eos

## components
- cmake3 (downloaded & compiled)
- afl (downloaded & compiled)
- xrootd (downloaded & compiled)
- eos (from git repository, compiled)

## steps
- alternatively use build script (see below)
- run `docker-compose up -d eos`
- installation of cmake, afl, eos, xrootd is now fully automated - retaining the section(s) below just as a note
- run `./eos-setup.sh` within the container to set up a mini, empty eos cluster
- run `afl-fuzz -m none -i /fuzz/mini -o /results/run(x) eos` (where x is the nth run of afl)
  - if EOS hangs/freezes, try `source /etc/sysconfig/eos /cf.env` to make sure the right envvars are set

## build script
This mildly clumsy script builds the docker containers we actually use for fuzzing - components can be built either with instrumentation enabled or disabled.
The build flag must be used with the instrumentation flag (can't compile without building containers).
The registry flag must be used with the push flag (can't push to a repository that isn't defined).

```
./build.sh [-r <registry> -i -b -p] [-h]

   OPTIONAL: 
   -r <registry> define a docker registry to push to
   -i compile with added instrumentation from afl-gcc
   -b actually do a build
   -p push to registry (-r must also be specified for -p to work)

   -h help
```

## process
- create a number of starter test cases
- optionally create a dictionary for afl to use
- use `afl-cmin` to cut down the number of test cases
- run afl-fuzz, one or multiple times
- collate the results from the respective crashes/ folders, then use afl-cmin to cut the number of test cases down again
- use afl-fuzz with -C flag on results obtained (in the crashes/ folder) to determine if any crashes are exploitable

## issues
the following files will cause errors in the compilation process:
```
mq/CMakeFiles/XrdMqClient-Static.dir/build.make   -> XrdMqSharedObject.cc.o -> _ZN31XrdMqSharedObjectChangeNotifier12tlSubscriberE
mgm/CMakeFiles/XrdEosMgm-Objects.dir/build.make   -> XrdMgmOfs.cc.o 	    -> _ZN31XrdMqSharedObjectChangeNotifier12tlSubscriberE
mgm/CMakeFiles/XrdEosMgm-Objects.dir/build.make   -> GeoTreeEngine.cc.o     -> _ZN3eos3mgm13GeoTreeEngine11tlGeoBufferE
common/CMakeFiles/eosCommon-Static.dir/build.make -> RWMutex.cc.o           -> _ZN3eos6common7RWMutex28orderCheckReset_staticthreadE
```
to circumvent this, modify the makefiles (first column) to compile the problem files (second column) with `/usr/bin/g++` instead of `/usr/local/bin/afl-g++`, eg.
```
[OLD] cd /eos/build/mq && /usr/local/bin/afl-g++ $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/XrdMqClient-Static.dir/XrdMqSharedObject.cc.o -c /eos/mq/XrdMqSharedObject.cc
[NEW] cd /eos/build/mq && /usr/bin/g++           $(CXX_DEFINES) $(CXX_INCLUDES) $(CXX_FLAGS) -o CMakeFiles/XrdMqClient-Static.dir/XrdMqSharedObject.cc.o -c /eos/mq/XrdMqSharedObject.cc
```

**IF EVER THE MGM NAMESPACE FAILS, CHECK THAT THE NAMESPACE PLUGIN IS LOADED IN XRD.CF.MGM**

## notes
- jemalloc must be disabled (in eos sysconfig) if ASAN is enabled
- also: if ASAN is enabled, add -pthreads to the compile flags (uncomment relevant lines in dockerfile) or compilation will fail
- definitely read the `notes_for_asan` documentation before using asan!!!

## todo
- write fuzzing harnesses for mgm, mq, fst
- consider fuzzing xrootd itself
- include eosd/fusex and figure out how to fuzz **that**
