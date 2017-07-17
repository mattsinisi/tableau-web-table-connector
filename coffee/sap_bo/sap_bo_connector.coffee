$ = require 'jquery'
_ = require 'underscore'
wdc_base = require '../connector_base/starschema_wdc_base.coffee'

PROXY_SERVER_CONFIG =
	protocol: 'http'

transformType = (type) ->
    switch type
        when 'STRING' then tableau.dataTypeEnum.string
        when 'DOUBLE', 'FLOAT' then  tableau.dataTypeEnum.float
        when 'INT32', 'INT64', 'UINT32', 'UINT64' then tableau.dataTypeEnum.int
        when 'DATE' then tableau.dataTypeEnum.date
        else tableau.dataTypeEnum.string

toTableauSchema = (fields)->
    fields.map (field)-> {id: field.name, dataType: transformType(field.type) }

wdc_base.make_tableau_connector
    steps:
        start:
            template: require './start.jade'
        configuration:
            template: require './configuration.jade'
        run:
            template: require './run.jade'

    transitions:
        "enter start": (data)->
          if data.error
            $('#error').show().text(data.error)
          else
            $('#error').hide().text()

        "start > configuration": (data) ->
            _.extend data, wdc_base.fetch_inputs("#state-start")

        "configuration > run": (data) ->
            _.extend data, wdc_base.fetch_inputs("#state-configuration")

        "enter configuration": (data, from,to, transitionTo) ->
            url = "#{PROXY_SERVER_CONFIG.protocol}://#{window.location.host}/sap/tablelist"
            $.ajax
                url: url
                dataType: 'json'
                data:
                    "wsdl": data.wsdl
                success: (data, textStatus, request) ->
                    for table in data
                        $("<option>").val(table).text(table).appendTo('#tables')
                error: (o, statusStr, err) ->
                    console.log o
                    console.error err
                    transitionTo "start", error: "While fetching '#{url}':\n#{o.responseText}\n#{err}"

        "enter run": (data) ->
            tableau.password = JSON.stringify
                credentials:
                    username: data.auth_username
                    password: data.auth_password

            delete data.auth_username
            delete data.auth_password

            wdc_base.set_connection_data data
            tableau.submit()

    columns: (connection_data, schemaCallback) ->
        connectionUrl = "#{PROXY_SERVER_CONFIG.protocol}://#{window.location.host}:#{PROXY_SERVER_CONFIG.port}/sap/tabledefinitions"
        config = JSON.parse(tableau.password)
        config.wsdl = connection_data.wsdl
        config.table = connection_data.table
        xhr_params =
            url: connectionUrl
            dataType: 'json'
            data: config
            success: (data, textStatus, request)->
                if data?.length > 0
                    schemaCallback [
                      id: config.table,
                      columns: toTableauSchema(data)
                    ]
            error: (err) ->
                console.error "Error:", err
        $.ajax xhr_params

    rows: (connection_data, table, doneCallback) ->
        connectionUrl = window.location.protocol + '//' + window.location.host + '/sap/tablerows'
        config = JSON.parse(tableau.password)
        config.wsdl = connection_data.wsdl
        config.table = connection_data.table
        _.extend connection_data, JSON.parse(tableau.password)
        xhr_params =
            url: connectionUrl
            dataType: 'json'
            data: config
            success: (data, textStatus, request)->
                table.appendRows(data)
                doneCallback()
            error: (err) ->
                console.error "Rows Error:", err
        $.ajax xhr_params
