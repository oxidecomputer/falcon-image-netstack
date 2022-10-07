Fullstack CI
=============

This builds the following falcon topology. Two sleds each connected to
two sidecars, each connected to a scrimlet.

```
                               +----------+
                               |          |
                               |  sled1   |
                               |          |
                               +----------+
                                 |      |
                                 |      |
   +-----------+  +.    +----------+  +----------+    .+  +-----------+
   |           |--| \   |          |  |          |   / |--|           |
   | scrimlet1 |--|  |--| sidecar1 |  | sidecar1 |--|  |--| scrimlet1 |
   |           |--| /   |          |  |          |   \ |--|           |
   +-----------+  +'    +----------+  +----------+    `+  +-----------+
                                 |      | 
                                 |      | 
                               +----------+
                               |          |
                               |  sled2   |
                               |          |
                               +----------+
```

## TODO

more info will be supplied once the topology is running properly
