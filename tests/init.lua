local yacl = require("yacl")

-- Inheritance from "Class" eliminates the warnings for "super", "instanceof", "parentof"
-- For example, class interfaces have "I" prefixes, but instance generators of these classes do not.
-- In a real modular project, this will not be required, since you will simply make a...
-- ...return from the module file via yacl.new

---@class Entity: Class
---@field x number
---@field y number
---@field z number
local IEntity = {}

function IEntity:constructor(x, y, z)
  self.x = x
  self.y = y
  self.z = z

  print(("Entity was constructed with coordinates (%.1f, %.1f, %.1f)"):format(x, y, z))
end

function IEntity:destructor()
  print("Entity was destructed!")
end

--- Teleports an entity to the point.
---@param x number
---@param y number
---@param z number
function IEntity:teleport(x, y, z)
  self.x = x
  self.y = y
  self.z = z
end

function IEntity:__tostring()
  return ("Entity(%.1f, %.1f, %.1f)"):format(self.x, self.y, self.z)
end

local Entity = yacl.new(IEntity)

---@class Person: Entity
---@field name string
---@field age number
local IPerson = {}

function IPerson:constructor(name, age, x, y, z)
  self:super("constructor", x, y, z)

  self.name = name
  self.age = age

  print(("Person was constructed with name %s and age %d!"):format(name, age))
end

function IPerson:destructor()
  print("Person was destructed! :(")
end

function IPerson:teleport(x, y, z)
  self:super("teleport", x, y, z)

  print("I hooked the IEntity teleport, yeah!", x, y, z)
end

function IPerson:teleport_to_the_oldman()
  self.age = 99
  -- Annotations of IEntity:teleport is dead :()
  self:teleport(2, 2, 8)
end

function IPerson:__tostring()
  return ("Person[%s, %d](%.1f, %.1f, %.1f)"):format(self.name, self.age, self.x, self.y, self.z)
end

function IPerson:__len()
  return self.age
end

local Person = yacl.new(IPerson, IEntity)

---@class Megahuman: Person
---@field power number
local IMegahuman = {}

function IMegahuman:constructor(name, age, power, x, y, z)
  self:super("constructor", name, age, x, y, z)

  self.power = power
end

function IMegahuman:destructor()
  print("Destructing mega robot human wtf")
end

function IMegahuman:teleport(x, y, z)
  self:super("teleport", x * self.power, y * self.power, z * self.power)

  print("ALERT! MEGA HUMAN TELEPORTING", self.x, self.y, self.z)
end

function IMegahuman:__call()
  print("Better call Saul!")
end

local Megahuman = yacl.new(IMegahuman, IPerson)

do
  local entity = Entity(2, 4, 5)
  assert(tostring(entity) == "Entity(2.0, 4.0, 5.0)")
  entity:teleport(1, 33, 7)
  print(("Entity: %s"):format(tostring(entity)))
  print(("Entity instanceof: %s"):format(entity:instanceof(IEntity)))
end

print("--------------------------------------------------------------------------")

do
  local person = Person("John", 18, 5, 4, 5)
  assert(tostring(person) == "Person[John, 18](5.0, 4.0, 5.0)")
  assert(#person == 18) -- Bro is really big xd.

  person:teleport(1900, 2000, -1)
  print(("Person after teleport: %s"):format(tostring(person)))

  person:teleport_to_the_oldman()

  print(("Person: %s"):format(tostring(person)))
  print(("Person instanceof of IEntity: %s"):format(person:instanceof(IEntity)))
  -- Parentof is not available for `person` and `entity`
  print(("Person instanceof of IPerson: %s"):format(person:instanceof(IPerson)))
  -- Instanceof is not available for `IPerson` and `IEntity`
  print(("IPerson instanceof of person: %s"):format(IPerson:parentof(person)))
end

print("--------------------------------------------------------------------------")

do
  local megahuman = Megahuman("Robot", 200, 9999, 0, 0, 0)
  assert(tostring(megahuman) == "Person[Robot, 200](0.0, 0.0, 0.0)")
  assert(#megahuman == 200)

  megahuman:teleport(2, 2, 2)
  megahuman:teleport_to_the_oldman()

  print(("Megahuman: %s"):format(tostring(megahuman)))
  print(("Megahuman instance of IEntity: %s"):format(megahuman:instanceof(IEntity)))
  print(("Megahuman instance of IPerson: %s"):format(megahuman:instanceof(IPerson)))
  print(("Megahuman instance of IMegahuman: %s"):format(megahuman:instanceof(IMegahuman)))
  print(("IEntity parent of IMegahuman: %s"):format(IEntity:parentof(megahuman)))
  print(("IPerson parent of IMegahuman: %s"):format(IPerson:parentof(megahuman)))
  print(("IMegahuman parent of IMegahuman: %s"):format(IMegahuman:parentof(megahuman)))
end
