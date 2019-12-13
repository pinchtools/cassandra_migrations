module CassandraMigrations
  class Migration
    class ViewDefinition
      def initialize()
        @columns = []
        @restrictions = {}
        @primary_keys = []
        @partition_keys = []
      end

      def to_create_cql
        cql = []
        build_table_selection(cql)
        build_restrictions(cql)
        build_pk_clause(cql)
        cql.join(' ')
      end

      def select(column_name, options={})
        @columns.push(column_name == :all ? "*" : column_name)
      end

      def restrict(column_name, options={})
        @restrictions[column_name.to_sym] = options.fetch(:with, "IS NOT NULL")
      end

      def options
        @options ? " WITH %s" % (@options.map {|option| build_option(option)}.join(" AND ")) : ''
      end

      def define_table(table_name)
        @table_name = table_name
      end

      def define_primary_keys(*keys)
        if !@primary_keys.empty?
          raise Errors::MigrationDefinitionError, 'Primary key defined twice for the same table.'
        end

        @primary_keys = keys.flatten
      end

      def define_partition_keys(*keys)
        if !@partition_keys.empty?
          raise Errors::MigrationDefinitionError, 'Partition key defined twice for the same table.'
        end

        @partition_keys = keys.flatten
      end

      def define_options(hash)
        @options = hash
      end

      private

      SPECIAL_OPTIONS_MAP = {
        compact_storage: 'COMPACT STORAGE',
        clustering_order: 'CLUSTERING ORDER'
      }.freeze

      def build_table_selection(cql)
        @columns = %w[*] if @columns.empty?

        if @table_name
          cql << "SELECT #{@columns.join(', ')} FROM #{@table_name}"
        else
          raise Errors::MigrationDefinitionError, 'No table defined for view.'
        end
      end

      def build_restrictions(cql)
        if @restrictions.empty?
          (@partition_keys + @primary_keys).each do |key|
            restrict(key)
          end
        end

        restrictions =
          @restrictions.each_with_object([]) do |(column_name, restriction), cql|
            cql << "#{column_name} #{restriction}"
          end
        cql << "WHERE #{restrictions.join(' AND ')}"
      end

      def build_pk_clause(cql)
        key_info = (@primary_keys - @partition_keys)
        key_info = ["(#{@partition_keys.join(', ')})", *key_info] if @partition_keys.any?

        if key_info.any?
          cql << "PRIMARY KEY(#{key_info.join(', ')})"
        else
          raise Errors::MigrationDefinitionError, 'No primary key defined.'
        end
      end

      def build_option(option)
        name, value = option
        cql_name = SPECIAL_OPTIONS_MAP.fetch(name, name.to_s)
        case name
        when :clustering_order
          "#{cql_name} BY (#{value})"
        when :compact_storage
          cql_name
        else
          #if complex option with nested hash, convert keys and values to proper string value
          if value.is_a?(Hash)
            value = "{#{value.map {|k, v| "'#{k}':'#{v}'"}.join(',')}}"
          end
          "#{cql_name} = #{value}"
        end
      end
    end
  end
end
