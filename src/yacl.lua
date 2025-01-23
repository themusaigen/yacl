local yacl = {
  _NAME = "Yacl",
  _DESCRIPTION = "Yet another class library",
  _VERSION = "1.1.0",
  _RELEASE = "release",
  _AUTHOR = "Musaigen"
}

---@class Class
---@field super fun(self: Class, key: any, ...: any): any
---@field instanceof fun(a: any, b: any): boolean # This function should be used when calling it from an instance.
---@field parentof fun(a: any, b: any): boolean # This function should be used when calling it from an class object.
---@field protected constructor fun(self: Class, ...: any)
---@field protected destructor fun(self: Class)

-- In Lua 5.1 and LuaJIT, which is based on it, adding destructor functionality requires taking roundabout paths.
local is_lua51 = _VERSION == "Lua 5.1"

-- Many metamethods, according to Lua 5.4, are needed to accurately determine...
-- ...whether an entity is a metamethod. This is necessary in order not to...
-- ...drag unnecessary things into the meta-table.
local metamethods = {
  __add = true,
  __sub = true,
  __mul = true,
  __div = true,
  __mod = true,
  __pow = true,
  __unm = true,
  __idiv = true,
  __band = true,
  __bor = true,
  __bxor = true,
  __bnot = true,
  __shl = true,
  __shr = true,
  __concat = true,
  __len = true,
  __eq = true,
  __lt = true,
  __le = true,
  __index = false, -- Can't change the __index metamethod.
  __newindex = true,
  __call = true,
  __tostring = true,
  __mode = true,
  __close = true,
  __metatable = true,
  __name = true,
  __pairs = true,
  __ipairs = true
}

--- Creates new class.
---@generic T
---@param object T
---@param parent? table
---@return fun(...: any): T
function yacl.new(object, parent)
  assert(type(object) == "table")
  -- If this class has a parent, we will check its validity.
  if parent then
    assert(type(parent) == "table")
  end

  --- Utility function to find value in classes chain.
  ---@param class table
  ---@param key any
  ---@return any, table?
  local function get_value_at_chain(class, key)
    while class do
      local value = rawget(class, key)
      if value then
        return value, class
      end
      class = rawget(class, "__parentobject")
    end
    return nil, nil
  end

  -- Create a local "super" function, which is needed to call the parent methods.
  local __super = function(self, key, ...)
    -- Iterate our parents until find needed function.
    local fun, class = get_value_at_chain(self.__parentobject, key)
    if fun and class then
      -- super refers only to functions
      assert(type(fun) == "function")

      -- Spoof parent to avoid stack overflow.
      local temp = self.__parentobject
      self.__parentobject = class.__parentobject

      -- Call it.
      local out = { fun(self, ...) }

      -- Restore spoofed parent.
      self.__parentobject = temp
      return table.unpack(out)
    end
  end

  -- Create a local "instanceof" function that checks whether the instance belongs to the class.
  local __instanceof = function(a, b)
    assert(type(a) == "table")
    assert(type(b) == "table")

    -- We are looking for an instance of the class among A and B.
    local instance = (a.__classobject) and (a) or (b)

    -- Then we select an object of the class.
    local class = (a.__classobject) and (b) or (a)

    -- We will go through all possible parents of this instance.
    while instance do
      -- The check for `classobject` is needed for the first iteration.
      -- The next `classobject` will always be nil.
      if (instance.__classobject == class) or (instance.__parentobject == class) then
        return true
      end

      -- We cycle through the next parent.
      instance = instance.__parentobject
    end
    return false
  end


  -- We will inject a similar function into a class object under a different name...
  -- ...so that, if necessary, it does not require the presence of an instance of the class.
  object.parentof = function(a, b)
    return __instanceof(a, b)
  end

  -- Inject parent to the object.
  object.__parentobject = parent

  -- Let's create a table with metamethods, which we will inject into the class.
  local meta = {
    -- Save them in a meta-table. Why not.
    __super = __super,
    __instanceof = __instanceof,
    __index = function(self, key)
      -- If the user tries to index the reserved function, we will return it.
      if key == "super" then
        return __super
      elseif key == "instanceof" then
        return __instanceof
      elseif key == "parentof" then
        -- It is not logical that an instance of a class can be the parent of another class.
        return nil
      elseif key == "destructor" then
        -- Fix double calling of destructor when parent has destructor, but child not.
        return rawget(object, key)
      end

      -- Try to get values from the chain.
      return get_value_at_chain(object, key)
    end
  }

  --- Just an utility to parse metamethods.
  ---@param target table
  ---@param origin table
  local function parse_metamethods(target, origin)
    for key, value in pairs(origin) do
      if metamethods[key] then
        target[key] = value
      end
    end
  end

  -- First we parse the metamethods of the parents, then the object.
  local p = parent
  local parents = {}

  -- Iterate through all parents to parse all metamethods later.
  while p do
    -- Add new parent to the list.
    parents[#parents + 1] = p

    -- Next paret.
    p = p.__parentobject
  end

  -- Parsing metamethods from oldest to newest parents.
  for i = #parents, 1, -1 do
    parse_metamethods(meta, parents[i])
  end

  parse_metamethods(meta, object)

  --- Utility for calling the destructor.
  ---@param instance? table
  local function call_destructor(instance)
    local class = instance
    while class do
      -- Ñheck that the destructor exists.
      local destructor = class.destructor
      if destructor then
        -- Check that the destructor is function.
        assert(type(destructor) == "function")

        -- Call it.
        destructor(instance)
      end

      -- Switching to the next parent.
      class = class.__parentobject
    end
  end

  -- In Lua 5.2 and higher, it is enough to simply assign the desired function to...
  -- ...the __gc meta-method.
  if not is_lua51 then
    if get_value_at_chain(object, "destructor") then
      meta.__gc = call_destructor
    end
  end

  return function(...)
    -- Creating a new instance of the class.
    local instance = setmetatable({ __classobject = object, __parentobject = parent }, meta)

    -- If there is a constructor, we will call it.
    local constructor = instance.constructor
    if constructor then
      -- Let's confirm that the constructor is a function.
      assert(type(constructor) == "function")

      -- Construct instance.
      constructor(instance, ...)
    end

    -- Trying to inject the destructor.
    if is_lua51 then
      -- We are checking whether there is a destructor that we should call.
      -- I think it's worth avoiding creating personal entities if it doesn't make sense.
      if get_value_at_chain(object, "destructor") then
        -- In Lua 5.1, the __gc metamethod can only be set to the userdata type.
        local proxy = newproxy(true)
        local mt = getmetatable(proxy)

        -- Set the __gc metamethod.
        mt.__gc = function()
          call_destructor(instance)
        end

        -- We can either just try to put a proxy in the table or use a rawset, which is preferable...
        -- ...since the installation of new elements may be blocked.
        rawset(instance, "__destructorproxy", proxy)
      end
    end

    -- Êeturning the newly created instance.
    return instance
  end
end

return yacl
