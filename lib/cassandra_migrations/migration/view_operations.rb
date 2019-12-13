require 'cassandra_migrations/migration/view_definition'

module CassandraMigrations
  class Migration
    module ViewOperations
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
        drop_cql =  "DROP MATERIALIZED VIEW #{view_name}"
        announce_suboperation drop_cql

        execute drop_cql
      end
    end
  end
end