local yacl = {
  _NAME = "Yacl",
  _DESCRIPTION = "Yet another class library",
  _VERSION = "1.0.0",
  _RELEASE = "release",
  _AUTHOR = "Musaigen"
}

---@class Class
---@field super fun(self: Class, key: any, ...: any): any
---@field instanceof fun(a: any, b: any): boolean # This function should be used when calling it from an instance.
---@field parentof fun(a: any, b: any): boolean # This function should be used when calling it from an class object.

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

  -- Create a local "super" function, which is needed to call the parent methods.
  local __super = function(self, key, ...)
    if parent then
      assert(type(parent[key]) == "function")

      return parent[key](self, ...)
    end
  end

  -- Create a local "instanceof" function that checks whether the instance belongs to the class.
  local __instanceof = function(a, b)
    if type(a) == "table" and a.__classobject then
      return (a.__classobject == b) or (a.__parentobject == b)
    elseif type(b) == "table" and b.__classobject then
      return (b.__classobject == a) or (b.__parentobject == a)
    else
      return false
    end
  end

  -- We will inject a similar function into a class object under a different name...
  -- ...so that, if necessary, it does not require the presence of an instance of the class.
  object.parentof = function(a, b)
    return __instanceof(a, b)
  end

  -- Let's create a table with metamethods, which we will inject into the class.
  local meta = {
    -- Save them in a meta-table. Why not.
    __super = __super,
    __instanceof = __instanceof,
    __index = function(self, key)
      -- If the user tries to index the super function, we will return it.
      if key == "super" then
        return __super
      elseif key == "instanceof" then
        return __instanceof
      elseif key == "parentof" then
        -- It is not logical that an instance of a class can be the parent of another class.
        return nil
      elseif key == "destructor" then
        -- Fix double calling of destructor when parent has destructor, but child not.
        return object[key]
      end

      -- If the desired value exists in the class, we return it.
      local value = object[key]

      -- If it doesn't exist, then we'll try to find it in the parent's class.
      if (value == nil) and (parent) then
        return parent[key]
      end

      return value
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

  -- First we parse the metamethods of the parent, then the object.
  if parent then
    parse_metamethods(meta, parent)
  end

  parse_metamethods(meta, object)

  --- Utility for calling the destructor.
  ---@param instance? table
  local function call_destructor(instance)
    local destructor = instance and instance.destructor
    -- Ñheck that the destructor exists.
    if destructor then
      --- Check that the destructor is function.
      assert(type(destructor) == "function")

      -- Call it.
      destructor(instance)
    end
  end

  -- In Lua 5.2 and higher, it is enough to simply assign the desired function to...
  -- ...the __gc meta-method.
  if not is_lua51 then
    if object.destructor or (parent and parent.destructor) then
      meta.__gc = function(self)
        call_destructor(self)
        call_destructor(self.__parentobject)
      end
    end
  end

  return function(...)
    -- Creating a new instance of the class.
    local instance = setmetatable({ __classobject = object, __parentobject = parent }, meta)

    -- If there is a constructor, we will call it.
    local constructor = object.constructor
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
      if object.destructor or (parent and parent.destructor) then
        -- In Lua 5.1, the __gc metamethod can only be set to the userdata type.
        local proxy = newproxy(true)
        local mt = getmetatable(proxy)

        -- Set the __gc metamethod.
        mt.__gc = function()
          call_destructor(instance)
          call_destructor(instance.__parentobject)
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
