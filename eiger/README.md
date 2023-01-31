# Eiger

# Periodic Self-Rehydrating Cache based on Spec v1 (2022-03-30)

Sample code execution:

1. Register a new function:

```
iex▶ Eiger.Cache.register_function(fn -> {:ok, "result2"} end, :weather3, 60000, 50000)

06:30:10.564 [debug] [msg: "Registering new function", fun: #Function<43.3316493/0 in :erl_eval.expr/6>, key: :weather3, ttl: 60000, refresh_interval: 50000]
 
06:30:10.569 [info] Starting function: weather3.
 
06:30:10.569 [info] [msg: "Function added to registry", count_registered: 1]
 
06:30:10.569 [info] Function weather3 completed successfullly!
:ok
```
Function gets exectured and stores the result for 60000 milliseconds. The next call will take place in 50000 milliseconds. When that happens the fresh result gets cached and expire_at will gets updated.


2. Get the cached result

```
iex▶ Eiger.Cache.get(:weather3)

06:36:57.455 [info] Get cached result of weather3 function
{:ok, "result2"}

```

3. When attempting to get the result before the function finish its execution, we'll get time out.

```
{:error, :timeout}
```