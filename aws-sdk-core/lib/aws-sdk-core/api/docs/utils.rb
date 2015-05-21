require 'set'
module Aws
  module Api
    module Docs
      module Utils

        include Seahorse::Model
        include Seahorse::Model::Shapes

        def tag(string)
          YARD::DocstringParser.new.parse(string).to_docstring.tags.first
        end

        def summary(string)
          if string
            YARD::DocstringParser.new.parse(string).to_docstring.summary
          else
            nil
          end
        end

        def operation_input_ref(operation, options = {})
          struct = StructureShape.new

          # add the response target input member if the operation is streaming
          if
            operation.output &&
            operation.output[:payload] &&
            operation.output[:payload_member][:streaming]
          then
            target = ShapeRef.new(shape: BlobShape.new)
            target[:response_target] = true
            target.documentation = "Specifies where to stream response data. You can provide the path where a file will be created on disk, or you can provide an IO object. If omitted, the response data will be loaded into memory and written to a StringIO object."
            struct.add_member(:response_target, target)
          end

          # copy existing input members
          if operation.input
            operation.input.shape.members.each do |member_name, member_ref|
              # TODO : allow filtering members
              struct.add_member(member_name, member_ref)
            end
          end

          ShapeRef.new(shape: struct)
        end

        # Given a shape reference, this function returns a Set of all
        # of the recursive shapes found in tree.
        def compute_recursive_shapes(ref, stack = [], recursive = Set.new)
          if ref && !stack.include?(ref.shape)
            stack.push(ref.shape)
            case ref.shape
            when StructureShape
              ref.shape.members.each do |_, member_ref|
                compute_recursive_shapes(member_ref, stack, recursive)
              end
            when ListShape
              compute_recursive_shapes(ref.shape.member, stack, recursive)
            when MapShape
              compute_recursive_shapes(ref.shape.value, stack, recursive)
            end
            stack.pop
          elsif ref
            recursive << ref.shape
          end
          recursive
        end

        # Given a shape ref, returns the type accepted when given as input.
        def input_type(ref, link = false)
          if BlobShape === ref.shape
            'IO,String'
          else
            output_type(ref, link)
          end
        end

        # Given a shape ref, returns the type returned in output.
        def output_type(ref, link = false)
          case ref.shape
          when StructureShape
            type = "Types::" + ref.shape.name
            link ? "{#{type}}" : type
          when ListShape
            "Array<#{output_type(ref.shape.member, link)}>"
          when MapShape
            "Hash<String,#{output_type(ref.shape.value, link)}>"
          when BlobShape
            ref[:streaming] ? 'IO,File' : 'String'
          when BooleanShape then 'Boolean'
          when FloatShape then 'Float'
          when IntegerShape then 'Integer'
          when StringShape then 'String'
          when TimestampShape then 'Time'
          else raise "unsupported shape #{ref.shape.class.name}"
          end
        end

      end
    end
  end
end
