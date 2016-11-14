--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "flows"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

application = _GET["application"]
application_filter = ""
hosts = _GET["hosts"]
key = _GET["key"]
host = _GET["host"]
vhost = _GET["vhost"]

network_id=_GET["network_id"]
network_name=_GET["network_name"]

prefs = ntop.getPrefs()
interface.select(ifname)
ifstats = aggregateInterfaceStats(interface.getStats())
ndpistats = interface.getnDPIStats()

if (network_id ~= nil) then

url = ntop.getHttpPrefix()..'/lua/flows_stats.lua?network_id='..network_id.."&network_name="..network_name

print [[
  <nav class="navbar navbar-default" role="navigation">
  <div class="navbar-collapse collapse">
    <ul class="nav navbar-nav">
]]
print("<li><a href=\"#\"> Network "..network_name)
print("</a></li>\n")

page = _GET["page"]

if(page == "flows") then
  print("<li class=\"active\"><a href=\"#\">Flows</a></li>\n")
else
  print("<li><a href=\""..url.."&page=flows\">Flows</a></li>")
end
if (page == "historical") then
  print("<li class=\"active\"><a href=\"#\"><i class='fa fa-area-chart fa-lg'></i></a></li>\n")
else
  print("<li><a href=\""..url.."&page=historical\"><i class='fa fa-area-chart fa-lg'></i></a></li>")
end

print [[
<li><a href="javascript:history.go(-1)"><i class='fa fa-reply'></i></a></li>
</ul>
</div>
</nav>
   ]]
end

if (page == "flows" or page == nil) then
num_param = 0
print [[
      <hr>
      <div id="table-flows"></div>
	 <script>
   var url_update = "]] 

print(ntop.getHttpPrefix()) 

print [[/lua/get_flows_data.lua]]

if(application ~= nil) then
   print("?application="..application)
   num_param = num_param + 1
   application_filter = '<span class="glyphicon glyphicon-filter"></span>'
end

if(host ~= nil) then
  if(num_param > 0) then print("&") else print("?") end
   print("host="..host)
   num_param = num_param + 1
end

if(vhost ~= nil) then
  if(num_param > 0) then print("&") else print("?") end
   print("vhost="..vhost)
   num_param = num_param + 1
end

if(hosts ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("hosts="..hosts)
  num_param = num_param + 1
end

if(key ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("key="..key)
  num_param = num_param + 1
end

if(network_id ~= nil) then
  if (num_param > 0) then
    print("&")
  else
    print("?")
  end
  print("network_id="..network_id)
  num_param = num_param + 1
end

print ('";')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_id.inc")
-- Set the flow table option

if(ifstats.vlan) then print ('flow_rows_option["vlan"] = true;\n') end

   print [[

	 var table = $("#table-flows").datatable({
			url: url_update , ]]
print ('rowCallback: function ( row ) { return flow_table_setID(row); },\n')

preference = tablePreferences("rows_number",_GET["perPage"])
if (preference ~= "") then print ('perPage: '..preference.. ",\n") end

print(" title: \"Active ".. (application or vhost or "").." Flows")

if(network_name ~= nil) then
   print(" [ Network "..network_name.." ]")
end

print [[",
         showFilter: true,
         showPagination: true,
]]

-- Automatic default sorted. NB: the column must be exists.
print ('sort: [ ["' .. getDefaultTableSort("flows") ..'","' .. getDefaultTableSortOrder("flows").. '"] ],\n')

print ('buttons: [ \'<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Applications ' .. application_filter .. '<span class="caret"></span></button> <ul class="dropdown-menu" role="menu" id="flow_dropdown">')

print('<li><a href="'..ntop.getHttpPrefix()..'/lua/flows_stats.lua')

n = 0
if(host ~= nil) then print('?host='..host) n = n + 1 end
if(vhost ~= nil) then
   if(n == 0) then print("?") else print("&") end
   print('vhost='..vhost)
end
if(network_id ~= nil) then 
   if(n == 0) then print("?") else print("&") end
   print('network_id='..network_id) 
   if(network_name ~= nil) then print('&network_name='..network_name) end
end

print('">All Proto</a></li>')

for key, value in pairsByKeys(ndpistats["ndpi"], asc) do
   class_active = ''
   if(key == application) then
      class_active = ' class="active"'
   end
   print('<li '..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/flows_stats.lua?application=' .. key)
   if(host ~= nil) then print('&host='..host) end
   if(vhost ~= nil) then print('&vhost='..vhost) end
   if(network_id ~= nil) then print('&network_id='..network_id) end
   if(network_name ~= nil) then print('&network_name='..network_name) end
   print('">'..key..'</a></li>')
end


print("</ul> </div>' ],\n")


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_top.inc")

if(ifstats.vlan) then
print [[
           {
           title: "VLAN",
         field: "column_vlan",
         sortable: true,
                 css: {
              textAlign: 'center'
           }
         },
]]
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_middle.inc")

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/flows_stats_bottom.inc")
end

if (page == "historical" and network_name ~= nil) then
  local netname_format = string.gsub(network_name, "_", "/")
  local rrd_file = _GET["rrd_file"]
  if (rrd_file == nil or rrd_file == "all") then
    rrd_file = "all"
  else
    rrd_file = getPathFromKey(netname_format).."/"..rrd_file
  end
  drawRRD(ifstats.id, nil, rrd_file, "1d", url.."&page=historical", 1, os.time() , "", nil)
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
