import SwiftUI

struct DataSourceComponent: UIComponent {
    let model: ComponentModel
    let context: UIContext

    init(model: ComponentModel, context: UIContext) {
        self.model = model
        self.context = context
    }

    var body: some View {
        Color.clear
            .frame(height: 0)
            .onAppear {
                context.dataSourceRegistry.register(buildConfig(from: model.resolvedProps))
            }
    }

    private func buildConfig(from props: [String: JSONValue]) -> DataSourceConfig {
        let id = props.string("id") ?? model.id
        let endpoint = props.string("endpoint") ?? ""
        var config = DataSourceConfig.makeDefault(id: id, endpoint: endpoint)

        config = DataSourceConfig(
            id: config.id,
            endpoint: props.string("endpoint") ?? config.endpoint,
            fetchPolicy: props.string("fetchPolicy") ?? config.fetchPolicy,
            pageSize: Int(props.double("pageSize") ?? Double(config.pageSize)),
            queryParam: props.string("queryParam") ?? config.queryParam,
            cursorParam: props.string("cursorParam") ?? config.cursorParam,
            localFiltering: props.bool("localFiltering") ?? config.localFiltering,
            remoteFiltering: props.bool("remoteFiltering") ?? config.remoteFiltering,
            debounceMs: Int(props.double("debounceMs") ?? Double(config.debounceMs)),
            sorting: props.bool("sorting") ?? config.sorting,
            defaultSortField: props.string("defaultSortField") ?? config.defaultSortField,
            defaultSortAscending: props.bool("defaultSortAscending") ?? config.defaultSortAscending,
            prefetchThreshold: Int(props.double("prefetchThreshold") ?? Double(config.prefetchThreshold)),
            keyField: props.string("keyField") ?? config.keyField
        )

        return config
    }
}
