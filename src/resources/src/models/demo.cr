# require "kemalyst"
# require "kemalyst/adapter/pg"

# class Demo < Kemalyst::Model
#   adapter pg
  
#   # the id, created_at and updated_at columns are automatically mapped for
#   # you.
#   sql_mapping({ 
#     name: ["TEXT", String]
#   })

#   def last_updated
#     last_updated = updated_at
#     if last_updated.is_a?(String)
#       last_updated = Time::Format.new("%F %X").parse(last_updated)
#     end
#     if last_updated.is_a?(Time)
#       formatter = Time::Format.new("%B %d, %Y")
#       last_updated = formatter.format(last_updated)
#     end
#     return last_updated
#   end
# end
