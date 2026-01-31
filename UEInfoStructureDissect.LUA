--UEInfoScanner and UEInfoStructureDissect are licensed under the MIT License by Eric Heijnen / Cheat Engine

local bitbytetobitnr={}
for i=0,7 do
  bitbytetobitnr[1<<i]=i
end


function UEngine_createStructureFromObject(address)
  if UEngine.UObject.Class==nil then return nil,'No UObject class offset' end
  local c=readPointer(address+UEngine.UObject.Class)
  if c then
    return UEngine_createStructureFromClass(c)
  end
end

function UEngine_createStructureFromClass(address)
  local UClassStruct=getStructure('UClass')
  if UClassStruct==nil then
    UClassStruct=createStructure('UClass')
    local e=UClassStruct.addElement()
    e.Name='vftable'
    e.Offset=0
    e.VarType=vtPointer

    e=UClassStruct.addElement()
    e.Name='Name'
    e.Offset=UEngine.UClass.Name
    e.PreviewPriority=1
    e.VarType=vtCustom
    e.CustomTypeName='UE FName to String'

    e=UClassStruct.addElement()
    e.Name='Class'
    e.Offset=UEngine.UClass.Class
    e.VarType=vtPointer
    e.ChildStruct=UClassStruct

    UClassStruct.addToGlobalStructureList()
  end

  local UObjectStruct=getStructure('UObject')
  if UObjectStruct==nil then  --create it
    UObjectStruct=createStructure('UObject')
    local e=UObjectStruct.addElement()
    e.Name='vftable'
    e.Offset=0
    e.VarType=vtPointer

    e=UObjectStruct.addElement()
    e.Name='Name'
    e.Offset=UEngine.UObject.Name
    e.PreviewPriority=1
    e.VarType=vtCustom
    e.CustomTypeName='UE FName to String'

    e=UObjectStruct.addElement()
    e.Name='Class'
    e.Offset=UEngine.UObject.Class
    e.VarType=vtPointer
    e.ChildStruct=UClassStruct

    UObjectStruct.addToGlobalStructureList()
  end

  --get the class of the object

  if address and address~=0 then
    local name=UObject_getName(address) --class is an UObject
    local properties=UClass_enumProperties(address)

    --check if this class is already defined, and if so, return that
    --local s=getStructure(name)
    --if s then
    --  return s
    --end


    if properties==nil then
      printf("UClass_enumProperties(0x%x) returned nil",address)

      return nil
    end


    s=UObjectStruct.clone(name)
    local e

    for name,info in pairs(properties) do
      e=s.addElement()
      e.Name=name
      e.Offset=info.offset
      e.Vartype=vtPointer --default

      if info.propertyType=='BoolProperty' then
        local bit=readByte(info.propertyAddress+UEngine.FProperty.BitMaskField+2)
        local bitnr=bitbytetobitnr[bit]
        if bitnr then
          e.Vartype=vtBinary
          e.BitStart=bitnr
          e.BitSize=1
        else
          e.Vartype=vtByte
        end
      end

      if info.propertyType=='IntProperty' then
        e.Vartype=vtDword
      end

      if info.propertyType=='ByteProperty' then
        e.Vartype=vtByte
      end

      if info.propertyType=='FloatProperty' then
        if readInteger(info.propertyAddress+UEngine.FProperty.Size)==4 then
          e.Vartype=vtSingle
        else
          e.Vartype=vtDouble
        end
      end

      if info.propertyType=='StructProperty' then
        --not sure, but
        if name:endsWith('Name') then
          e.Vartype=vtCustom
          e.CustomTypeName='UE FName to String'
        else
          e.Vartype=vtByteArray
          e.ByteSize=readInteger(info.propertyAddress+UEngine.FProperty.Size)
        end
      end

      if info.propertyType=='StrProperty' then
        e.Vartype=vtPointer
        e.ChildStruct=getStructure('widestring')
      end

      if info.propertyType=='ClassProperty' then
        e.Vartype=vtPointer
        e.ChildStruct=getStructure('UClass')
      end

      if info.propertyType=='ObjectProperty' then
        e.Vartype=vtPointer
        e.ChildClassName='Type: 0x'..string.format("%x",readPointer(info.propertyAddress+UEngine.FProperty.ObjectClassType))
        e.OnCreateChild=function(element, address)
          print("goobelywoo")
          local newstruct
          if address then
            printf("Creating using address %x", address)
            newstruct=UEngine_createStructureFromObject(address) --prefer this as it might be an inherited object so it shows more fields
            if newstruct==nil then
              printf("awww")
            end
          end
          if newstruct==nil then
            printf("Creating using info: %s", element.ChildClassName)
            local cstr=tonumber(element.ChildClassName:sub(7))
            if cstr then
              newstruct=UEngine_createStructureFromClass(cstr)
            end
          end

          if newstruct then
            --print("Weeeeee")
            return newstruct
          else
            --if messageDialog('Couldn''t figure out the structure. Let CE try?',mtConfirmation,mbYes,mbNo)==mrYes then
            --  return nil,true --let CE try it
            --else
             -- print("humbug")
              return nil
            --end
          end
        end
      end


      if e.ChildClassName=='' then
        e.ChildClassName=string.format('Property: %x',info.propertyAddress)
      end


    end


    s.addToGlobalStructureList()
    return s
  end
end

--createStructureFromObject(readPointer('GEngine'))
--createStructureFromObject(0x25B23C2A10)

function registerUEngineStructureLookupCallbacks()
  --register a structure dissect that gets the base address and dissects it
  if UEngineStructNameLookup then
    unregisterStructureNameLookup(UEngineStructNameLookup)
    UEngineStructNameLookup=nil
  end

  UEngineStructNameLookup=registerStructureNameLookup(function(address)
    local obj=UEngine_findStructureStart(address)
    if obj then
      local class=readPointer(obj+UEngine.UObject.Class)
      local nameindex=readPointer(class+UEngine.UClass.Name)

      if nameindex and nameindex>0 then
        local name=UEngine.IndexToName[nameindex]

        if name then
          return name,obj
        end
      end
    end
  end,true)

  if UEngineStructDissect then
    unregisterStructureDissectOverride2(UEngineStructDissect)
    UEngineStructDissect=nil
  end

  print("poop init")

  UEngineStructDissect=registerStructureDissectOverride2(function(address)
    print("poop 2")
    if UEngine_findStructureStart(address) then
      local s=UEngine_createStructureFromObject(address)
      return s
    else
      return nil --let CE guess it
    end
  end)

end

