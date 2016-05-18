require "yaml"

# Base class for a simple ORM mapping to a SQL database.
# This class looks for a `config/database.yml` for the database configuration.
# a sample database.yml will look like:
# ```
# mysql:
#   database: blog_test
#   host: 127.0.0.1
#   port: 3306
#   username: blog
#   password: ${DB_PASSWORD}
# pg:
#   database: ${DATABASE_URL} 
# sqlite:
#   database: config/blog_test.db
# ```
# Note: You can leverage environment variables using ${} syntax.
#
# ## Usage
# Here is an example of a Model:
# ```
# class Post < Model
#   adapter mysql
#   sql_mapping({ 
#     name: "VARCHAR(255)" },
#     body: "TEXT" }
#   })
# end
# ```
#
# ### Fields
#
# To define the fields for this model, you need to provide a hash with the name
# of the field as a `Symbol` and the MySQL type as a `String`.  This can include
# any other options that MySQL provides to you.  

# 3 Fields are automatically created for you:  id, created_at, updated_at.
# These will also be set for you when you use the `save` method.

# MySQL field definitions for id, created_at, updated_at

# ```mysql
#   id INT NOT NULL AUTO_INCREMENT
#   # Your fields go here
#   created_at DATE
#   updated_at DATE 
#   PRIMARY KEY (id)
# ```

# ### DDL Built in

# ```crystal
# Post.drop #drop the table

# Post.create #create the table

# Post.clear #truncate the table
# ```

# ### DML

# #### Find All

# ```crystal
# posts = Post.all
# if posts
#   posts.each do |post|
#     puts post.name
#   end
# end
# ```

# #### Find One

# ```crystal
# post = Post.find 1
# if post
#   puts post.name
# end
# ```

# #### Insert

# ```crystal
# post = Post.new
# post.name = "Amethyst Rocks!"
# post.body = "Check this out."
# post.save
# ```

# #### Update

# ```crystal
# post = Post.find 1
# post.name = "Amethyst Really Rocks!"
# post.save
# ```

# #### Delete

# ```crystal
# post = Post.find 1
# post.destroy
# puts "deleted" unless post
# ```

# ### Where 

# The where clause will give you full control over your query. 

# When using the `all` method, the SQL selected fields will always match the
# fields specified in the model.  If you need different fields, consider
# creating a new model.

# Always pass in parameters to avoid SQL Injection.  Use a symbol in your query
# i.e. `:param` for parameter replacement.  Check out
# [waterlink/crystal-mysql](https://github.com/waterlink/crystal-mysql) for more
# details.

# ```crystal
# posts = Post.all("WHERE name LIKE :name", {"name" => "Joe%"})
# if posts
#   posts.each do |post|
#     puts post.name
#   end
# end

# # ORDER BY Example
# posts = Post.all("ORDER BY created_at DESC")

# # JOIN Example
# posts = Post.all("JOIN comments c ON c.post_id = post.id 
#                   WHERE c.name = :name 
#                   ORDER BY post.created_at DESC", 
#                   {"name" => "Joe"})

# ``` 
# 
# ## Connection Pool
#
# A connection pool is leveraged to reduce the cost of opening and closing
# connections.
abstract class Kemalyst::Model

  # specify the database adapter you will be using for this model. 
  # mysql, pg, sqlite, etc.
  macro adapter(name)
    unless @@database
      yaml_file = File.read("config/database.yml")
      yaml = YAML.parse(yaml_file)
      settings = yaml["{{name.id}}"]
      @@database = Kemalyst::Adapter::{{name.id.capitalize}}.new(settings)
    end
  end  

  # sql_mapping is the mapping between columns in your database and the fields
  # in this model.  proerties will be created for each field.  The type of the
  # field is specific to the database you are using.  You may specify other
  # criteria for each field like `NOT NULL` and Referential Integrity. This
  # allows you to take full advantage of the database of choice.
  # you may also specify a specific table_name and if you want the timestamps
  # or not.  This will help with backward compatibility of existing databases.
  macro sql_mapping(names, table_name = nil, timestamps = true)
    {% name_space = @type.name.downcase.id %}
    {% table_name = name_space + "s" unless table_name %}
    # Table Name
    @@table_name = "{{table_name}}"
    #Create the properties
    property id
    {% for name, type in names %}
      property {{name.id}}
    {% end %}
    {% if timestamps %}
    property created_at
    property updated_at
    {% end %}
   
    # Create the from_sql method
    def self.from_sql(result)
      {{name_space}} = {{@type.name.id}}.new
      {{name_space}}.id = result[0]
      {% i = 1 %}
      {% for name, type in names %}
        # Need to find a way to map to other types based on SQL type
        {{name_space}}.{{name.id}} = result[{{i}}]
        {% i += 1 %}
      {% end %}

      {% if timestamps %}
        {{name_space}}.created_at = result[{{i}}]
        {{name_space}}.updated_at = result[{{i + 1}}]
      {% end %}
      return {{name_space}}
    end

    # keep a hash of the fields to be used for mapping
    def self.fields(fields = {} of String => String)
        {% for name, type in names %}
        fields["{{name.id}}"] = "{{type.id}}"
        {% end %}
        {% if timestamps %}
        fields["created_at"] = "TIMESTAMP"
        fields["updated_at"] = "TIMESTAMP"
        {% end %}
        return fields
    end

    # keep a hash of the params that will be passed to the adapter.
    def params
      return {
          {% for name, type in names %}
            "{{name.id}}" => {{name.id}},
          {% end %}
          {% if timestamps %}
            "created_at" => created_at,
            "updated_at" => updated_at,
          {% end %}
      }
    end

  end #End of Fields Macro


  # Clear is used to remove all rows from the table and reset the counter for
  # the id.
  def self.clear
    if db = @@database
      db.clear(@@table_name)
    end
    return true
  end

  # Drop will drop the table completely.  This will lose data so be very
  # careful with this call.
  def self.drop
    if db = @@database
      db.drop(@@table_name)
    end
    return true
  end

  # Create will create the table for you based on the sql_mapping specified.
  def self.create
    if db = @@database
      db.create(@@table_name, fields)
    end
    return true
  end

  # Migrate will examine the current schema and additively update to match the
  # model.
  def self.migrate
    if db = @@database
      db.migrate(@@table_name, fields)
    end
    return true
  end

  # The save method will check to see if the @id exists yet.  If it does it
  # will call the update method, otherwise it will call the create method.
  # This will update the timestamps apropriately.
  def save
    if db = @@database
      if value = @id
        updated_at = Time.now
        db.update(@@table_name, self.class.fields, value, params)
      else
        @created_at = Time.now
        @updated_at = Time.now
        @id = db.insert(@@table_name, self.class.fields, params)
      end
    end
    return true
  end

  # Destroy will remove this from the database.
  def destroy
    if db = @@database
      db.delete(@@table_name, @id)
    end
    return true
  end
  
  # All will return all rows in the database. The clause allows you to specify
  # a WHERE, JOIN, GROUP BY, ORDER BY and any other SQL92 compatible query to
  # your table.  The results will be an array of instantiated instances of
  # your Model class.  This allows you to take full advantage of the database
  # that you are using so you are not restricted or dummied down to support a
  # DSL.  
  def self.all(clause = "", params = {} of String => String)
    return self.query(@@table_name, fields({"id" => "INT"}), clause, params)
  end
  
  # find returns the row with the id specified.
  def self.find(id)
    return self.query_one(@@table_name, fields({"id" => "INT"}), id)
  end
  
  # query performs the select statement and calls the from_sql with the
  # results.
  def self.query(table_name, fields, clause, params = {} of String => String)
    rows = [] of self
    if db = @@database
      results = db.select(table_name, fields, clause, params)
      if results.is_a?(Array)
        if results.size > 0
          results.each do |result|
            rows << self.from_sql(result)
          end
        end
      end
    end
    return rows
  end

  # query_one is a convenience method for only returning the first instance of a
  # query.
  def self.query_one(table_name, fields, id)
    row = nil
    if db = @@database
      results = db.select_one(table_name, fields, id)
      if results.is_a?(Array)
        if results.size > 0
          row = self.from_sql(results.first)
        end
      end
    end
    return row
  end


end



