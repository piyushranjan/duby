module Duby::AST
  class FunctionalCall < Node
    include Named
    attr_accessor :parameters, :block, :cast, :inlined
    alias cast? cast
        
    def initialize(parent, line_number, name, &kids)
      super(parent, line_number, &kids)
      @parameters, @block = children
      @name = name
      @cast = false
    end
        
    def infer(typer)
      @self_type ||= typer.self_type

      unless @inferred_type
        if @inlined
          @inferred_type = @inlined.infer(typer)
        else
          receiver_type = @self_type
          should_defer = false
        
          parameter_types = parameters.map do |param|
            typer.infer(param) || should_defer = true
          end
        
          unless should_defer
            if parameters.size == 1 && typer.known_types[name]
              # cast operation
              resolved!
              self.cast = true
              @inferred_type = typer.known_types[name]
            else
              @inferred_type = typer.method_type(receiver_type, name,
                                                 parameter_types)
              if @inferred_type.kind_of? InlineCode
                @inlined = @inferred_type.inline(typer.transformer, self)
                @inferred_type = @inlined.infer(typer)
              end
            end
          end
        end
        
        @inferred_type ? resolved! : typer.defer(self)
      end
        
      @inferred_type
    end
  end
  
  class Call < Node
    include Named
    attr_accessor :target, :parameters, :block, :inlined

    def initialize(parent, line_number, name, &kids)
      super(parent, line_number, children, &kids)
      @target, @parameters, @block = children
      @name = name
    end

    def infer(typer)
      unless @inferred_type
        if @inlined
          @inferred_type = @inlined.infer(typer)
        else
          receiver_type = typer.infer(target)
          should_defer = receiver_type.nil?
          parameter_types = parameters.map do |param|
            typer.infer(param) || should_defer = true
          end
        
          unless should_defer
            @inferred_type = typer.method_type(receiver_type, name,
                                               parameter_types)
            if @inferred_type.kind_of? InlineCode
              @inlined = inferred_type.inline(typer.transformer, self)
              @inferred_type = @inlined.infer(typer)
            end
          end
        end
        
        @inferred_type ? resolved! : typer.defer(self)
      end
        
      @inferred_type
    end
  end
end