require 'cassandra_migrations/migration/view_definition'

module CassandraMigrations
  class Migration
    module ViewOperations
      def auto_create_view(view_class)
        unless defined?(::Cequel)
          raise NotImplementedError,
            "The `auto_create_view` operation requires https://github.com/cequel/cequel"
        end

        view_schema = view_class.table_schema

        if_table_exists?(view_class.model_class.table_name) do |table_name|
          create_view(view_class.table_name,
            table: table_name,
            partition_keys: view_schema.partition_key_column_names,
            primary_keys: view_schema.clustering_column_names,
            options: {
              clustering_order: clustering_order_cql_for(view_schema)
            }
          )
        end
      end

      def create_view(view_name, options = {})
        view_definition = ViewDefinition.new
        view_definition.define_table(options[:table]) if options[:table]
        view_definition.define_primary_keys(options[:primary_keys]) if options[:primary_keys]
        view_definition.define_partition_keys(options[:partition_keys]) if options[:partition_keys]
        view_definition.define_options(options[:options]) if options[:options]

        yield view_definition if block_given?

        announce_operation "create_view(#{view_name})"

        create_cql =  "CREATE MATERIALIZED VIEW #{view_name} AS "
        create_cql << view_definition.to_create_cql
        create_cql << view_definition.options

        announce_suboperation create_cql

        execute create_cql
      end

      def drop_view(view_name)
        announce_operation "drop_view(#{view_name})"
        drop_cql =  "DROP MATERIALIZED VIEW IF EXISTS #{view_name}"
        announce_suboperation drop_cql

        execute drop_cql
      end
    end
  end
end
