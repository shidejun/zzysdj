--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "top_talkers"
require "json"

local top_os_local_intf = {}

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/lua/modules/top_scripts/?.lua;" .. package.path
  local new = require("top_aggregate")
  if (type(new) ~= "table") then new = {} end
  -- Add pro methods to local method table
  for k,v in pairs(new) do
    top_os_local_intf[k] = v
  end
end

local function getTopOSLocal(ifid, ifname)
  return getCurrentTopGroupsSeparated(ifid, ifname, 10, true, false,
                                      nil, nil, top_os_local_intf.key,
                                      top_os_local_intf.JSONkey, true, true, nil,
                                      top_os_local_intf.uniqueKey)
end

local function getTopOSLocalBy(ifid, ifname, filter_col, filter_val)
  return getCurrentTopGroupsSeparated(ifid, ifname, 10, true, false,
                                      filter_col, filter_val, top_os_local_intf.key,
                                      top_os_local_intf.JSONkey, true, true, nil,
                                      top_os_local_intf.uniqueKey)
end

local function getTopOSLocalClean(ifid, ifname, param)
  top = getCurrentTopGroups(ifid, ifname, 5, false, false,
                                      nil, nil, top_os_local_intf.key,
                                      top_os_local_intf.JSONkey, true, param,
                                      top_os_local_intf.uniqueKey)
  section_beginning = string.find(top, '%[')
  if (section_beginning == nil) then
    return("[ ]\n")
  else
    return(string.sub(top, section_beginning))
  end
end

local function topOSLocalSectionInTableOP(tblarray, arithOp)
  local ret = {}
  local outer_cnt = 1
  local num_glob = 1

  for _,tbl in pairs(tblarray) do
    for _,outer in pairs(tbl) do
      if (ret[outer_cnt] == nil) then ret[outer_cnt] = {} end
      for key, value in pairs(outer) do
        for _,record in pairs(value) do
          local found = false
          if (ret[outer_cnt][key] == nil) then ret[outer_cnt][key] = {} end
          for _,el in pairs(ret[outer_cnt][key]) do
            if (found == false and el["address"] == record["address"]) then
              el["value"] = arithOp(el["value"], record["value"])
              found = true
            end
          end
          if (found == false) then
            ret[outer_cnt][key][num_glob] = record
            num_glob = num_glob + 1
          end
        end
      end
    end
  end

  return ret
end

local function printTopOSLocalTable(tbl)
  local rsp = "{\n"

  for i,v in pairs(tbl) do
    local outouterlooped = 0
    for dk,dv in pairs(v) do
      rsp = rsp..'"'..dk..'": [\n'
      local keys = getKeys(dv, "value")
      local outerlooped = 0
      for tv,tk in pairsByKeys(keys, rev) do
        rv = dv[tk]
        rsp = rsp.."{ "
        local looped = 0
        for k,v in pairs(rv) do
          rsp = rsp..'"'..k..'": '
          if (k == "value") then
            rsp = rsp..tostring(v)
          else
            rsp = rsp..'"'..v..'"'
          end
          rsp = rsp..", "
          looped = looped + 1
        end
        if (looped > 0) then
          rsp = string.sub(rsp, 1, -3)
        end
        rsp = rsp.."},\n"
        outerlooped = outerlooped + 1
      end
      if (outerlooped > 0) then
        rsp = string.sub(rsp, 1, -3)
      end
      rsp = rsp.."],\n"
      outouterlooped = outouterlooped + 1
    end
    if (outouterlooped > 0) then
      rsp= string.sub(rsp, 1, -3)
    end
  end

  rsp = rsp.."\n}"

  return rsp

end

local function getTopOSLocalFromJSONDirection(table, wantedDir, add_vlan)
  local elements = ""

  -- For each VLAN, get os and concatenate them
  for i,vlan in pairs(table["vlan"]) do
      local vlanid = vlan["label"]
      local vlanname = vlan["name"]
      -- XXX os is an array of (senders, receivers) pairs?
      for i2,os in pairs(vlan[top_os_local_intf.JSONkey]) do
        -- os is { "senders": [...], "receivers": [...] }
        for k2,direction in pairs(os) do
          -- direction is "senders": [...] or "receivers": [...]
          if (k2 ~= wantedDir) then goto continue end
          -- scan os
          for i2,os in pairs(direction) do
            -- os is { "label": ..., "value": ..., "url": ... }
            elements = elements.."{ "
            local n_el = 0
            for k3,v3 in pairs(os) do
              elements = elements..'"'..k3..'": '
              if (k3 == "value") then
                elements = elements..tostring(v3)
              else
                elements = elements..'"'..v3..'"'
              end
              elements = elements..", "
              n_el = n_el + 1
            end
            if (add_vlan ~= nil) then
              elements = elements..'"vlanm": "'..vlanname..'", '
              elements = elements..'"vlan": "'..vlanid..'", '
            end
            if (n_el ~= 0) then
              elements = string.sub(elements, 1, -3)
            end
            elements = elements.." },\n"
          end
          ::continue::
        end
      end
  end

  return elements
end

local function printTopOSLocalFromTable(table, add_vlan)
  if (table == nil or table["vlan"] == nil) then return "[ ]\n" end

  local elements = "{\n"
  elements = elements..'"senders": [\n'
  local result = getTopOSLocalFromJSONDirection(table, "senders", add_vlan)
  if (result ~= "") then
    result = string.sub(result, 1, -3) --remove comma
  end
  elements = elements..result
  elements = elements.."],\n"
  elements = elements..'"receivers": [\n'
  result = getTopOSLocalFromJSONDirection(table, "receivers", add_vlan)
  if (result ~= "") then
    result = string.sub(result, 1, -3) --remove comma
  end
  elements = elements..result
  elements = elements.."]\n"
  elements = elements.."}\n"

  return elements
end

local function getTopOSFromJSON(content, add_vlan)
  if(content == nil) then return("[ ]\n") end
  local table = parseJSON(content)
  local rsp = printTopOSLocalFromTable(table, add_vlan)
  if (rsp == nil or rsp == "") then return "[ ]\n" end
  return rsp
end

local function getHistoricalTopOSLocal(ifid, ifname, epoch, add_vlan)
  if (epoch == nil) then
    return("[ ]\n")
  end
  return getTopOSLocalFromJSON(ntop.getMinuteSampling(ifid, tonumber(epoch)), add_vlan)
end

top_os_local_intf.name = "Local Operating Systems"
top_os_local_intf.infoScript = "hosts_stats.lua"
top_os_local_intf.infoScriptKey = "os"
top_os_local_intf.key = "os"
top_os_local_intf.JSONkey = "local os"
top_os_local_intf.uniqueKey = "top_local_os"
top_os_local_intf.getTop = getTopOSLocal
top_os_local_intf.getTopBy = getTopOSLocalBy
top_os_local_intf.getTopClean = getTopOSLocalClean
top_os_local_intf.getTopFromJSON = getTopOSLocalFromJSON
top_os_local_intf.printTopTable = printTopOSLocalTable
top_os_local_intf.getHistoricalTop = getHistoricalTopOSLocal
top_os_local_intf.topSectionInTableOp = topOSLocalSectionInTableOP
top_os_local_intf.numLevels = 2

return top_os_local_intf
