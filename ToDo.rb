#!/usr/bin/env ruby

require 'json'
require 'date'

class Task
  attr_accessor :id, :title, :description, :completed, :priority, :created_at, :due_date

  def initialize(title, description = '', priority = 'medium', due_date = nil)
    @id = generate_id
    @title = title
    @description = description
    @completed = false
    @priority = priority
    @created_at = DateTime.now
    @due_date = due_date ? DateTime.parse(due_date) : nil
  end

  def to_hash
    {
      id: @id,
      title: @title,
      description: @description,
      completed: @completed,
      priority: @priority,
      created_at: @created_at.to_s,
      due_date: @due_date ? @due_date.to_s : nil
    }
  end

  def self.from_hash(hash)
    task = allocate
    task.id = hash['id']
    task.title = hash['title']
    task.description = hash['description']
    task.completed = hash['completed']
    task.priority = hash['priority']
    task.created_at = DateTime.parse(hash['created_at'])
    task.due_date = hash['due_date'] ? DateTime.parse(hash['due_date']) : nil
    task
  end

  def status
    @completed ? '✓' : '○'
  end

  def priority_symbol
    case @priority.downcase
    when 'high' then '🔴'
    when 'medium' then '🟡'
    when 'low' then '🟢'
    else '⚪'
    end
  end

  def overdue?
    @due_date && @due_date < DateTime.now && !@completed
  end

  private

  def generate_id
    Time.now.to_f.to_s.gsub('.', '')[0..10].to_i
  end
end

class TodoManager
  DATA_FILE = 'tasks.json'

  def initialize
    @tasks = load_tasks
  end

  def add_task(title, description = '', priority = 'medium', due_date = nil)
    if title.strip.empty?
      puts "❌ Task title cannot be empty!"
      return
    end

    task = Task.new(title.strip, description.strip, priority, due_date)
    @tasks << task
    save_tasks
    puts "✅ Task '#{task.title}' added successfully! (ID: #{task.id})"
  end

  def list_tasks(filter = 'all')
    if @tasks.empty?
      puts "📝 No tasks found. Add some tasks to get started!"
      return
    end

    filtered_tasks = case filter.downcase
                    when 'completed' then @tasks.select(&:completed)
                    when 'pending' then @tasks.reject(&:completed)
                    when 'overdue' then @tasks.select(&:overdue?)
                    else @tasks
                    end

    if filtered_tasks.empty?
      puts "📝 No #{filter} tasks found."
      return
    end

    puts "\n" + "=" * 80
    puts "📋 TODO LIST - #{filter.upcase} TASKS (#{filtered_tasks.length})"
    puts "=" * 80

    filtered_tasks.sort_by(&:created_at).each_with_index do |task, index|
      status_color = task.completed ? "\e[32m" : (task.overdue? ? "\e[31m" : "\e[37m")
      reset_color = "\e[0m"
      
      puts "#{index + 1}. #{status_color}#{task.status} [#{task.id}] #{task.priority_symbol} #{task.title}#{reset_color}"
      
      unless task.description.empty?
        puts "   📄 #{task.description}"
      end
      
      puts "   📅 Created: #{task.created_at.strftime('%Y-%m-%d %H:%M')}"
      
      if task.due_date
        due_status = task.overdue? ? " (⚠️  OVERDUE)" : ""
        puts "   ⏰ Due: #{task.due_date.strftime('%Y-%m-%d %H:%M')}#{due_status}"
      end
      
      puts ""
    end
  end

  def complete_task(id)
    task = find_task(id)
    return unless task

    if task.completed
      puts "ℹ️  Task '#{task.title}' is already completed!"
      return
    end

    task.completed = true
    save_tasks
    puts "🎉 Task '#{task.title}' marked as completed!"
  end

  def uncomplete_task(id)
    task = find_task(id)
    return unless task

    if !task.completed
      puts "ℹ️  Task '#{task.title}' is already pending!"
      return
    end

    task.completed = false
    save_tasks
    puts "🔄 Task '#{task.title}' marked as pending!"
  end

  def delete_task(id)
    task = find_task(id)
    return unless task

    @tasks.delete(task)
    save_tasks
    puts "🗑️  Task '#{task.title}' deleted successfully!"
  end

  def update_task(id, title = nil, description = nil, priority = nil, due_date = nil)
    task = find_task(id)
    return unless task

    task.title = title.strip unless title.nil? || title.strip.empty?
    task.description = description.strip unless description.nil?
    task.priority = priority unless priority.nil?
    
    if due_date
      task.due_date = due_date.downcase == 'none' ? nil : DateTime.parse(due_date)
    end

    save_tasks
    puts "📝 Task updated successfully!"
  end

  def search_tasks(query)
    results = @tasks.select do |task|
      task.title.downcase.include?(query.downcase) ||
      task.description.downcase.include?(query.downcase)
    end

    if results.empty?
      puts "🔍 No tasks found matching '#{query}'"
      return
    end

    puts "\n🔍 SEARCH RESULTS for '#{query}' (#{results.length} found)"
    puts "-" * 50

    results.each do |task|
      status_color = task.completed ? "\e[32m" : (task.overdue? ? "\e[31m" : "\e[37m")
      reset_color = "\e[0m"
      
      puts "#{status_color}#{task.status} [#{task.id}] #{task.priority_symbol} #{task.title}#{reset_color}"
      puts "   📄 #{task.description}" unless task.description.empty?
      puts ""
    end
  end

  def stats
    total = @tasks.length
    completed = @tasks.count(&:completed)
    pending = total - completed
    overdue = @tasks.count(&:overdue?)

    puts "\n📊 TASK STATISTICS"
    puts "-" * 30
    puts "📝 Total Tasks: #{total}"
    puts "✅ Completed: #{completed}"
    puts "⏳ Pending: #{pending}"
    puts "⚠️  Overdue: #{overdue}"
    
    if total > 0
      completion_rate = (completed.to_f / total * 100).round(1)
      puts "📈 Completion Rate: #{completion_rate}%"
    end
    puts ""
  end

  def clear_completed
    completed_count = @tasks.count(&:completed)
    
    if completed_count == 0
      puts "ℹ️  No completed tasks to clear."
      return
    end

    @tasks.reject!(&:completed)
    save_tasks
    puts "🧹 Cleared #{completed_count} completed task(s)!"
  end

  private

  def find_task(id)
    task = @tasks.find { |t| t.id == id.to_i }
    
    if task.nil?
      puts "❌ Task with ID #{id} not found!"
      return nil
    end
    
    task
  end

  def load_tasks
    return [] unless File.exist?(DATA_FILE)
    
    begin
      data = JSON.parse(File.read(DATA_FILE))
      data.map { |task_data| Task.from_hash(task_data) }
    rescue JSON::ParserError
      puts "⚠️  Warning: Could not parse tasks file. Starting fresh."
      []
    end
  end

  def save_tasks
    File.write(DATA_FILE, JSON.pretty_generate(@tasks.map(&:to_hash)))
  end
end

class TodoCLI
  def initialize
    @manager = TodoManager.new
  end

  def run
    puts "\n🎯 Welcome to Todo List Manager!"
    puts "Type 'help' for available commands.\n\n"

    loop do
      print "todo> "
      input = gets.chomp.strip
      
      break if input.downcase == 'quit' || input.downcase == 'exit'
      
      process_command(input)
    end

    puts "\n👋 Goodbye! Your tasks have been saved."
  end

  private

  def process_command(input)
    return if input.empty?
    
    parts = input.split(' ', 2)
    command = parts[0].downcase
    args = parts[1] || ''

    case command
    when 'add', 'a'
      handle_add_command(args)
    when 'list', 'ls', 'l'
      filter = args.empty? ? 'all' : args
      @manager.list_tasks(filter)
    when 'complete', 'done', 'c'
      @manager.complete_task(args.to_i) if args
    when 'uncomplete', 'undone', 'u'
      @manager.uncomplete_task(args.to_i) if args
    when 'delete', 'remove', 'del', 'd'
      @manager.delete_task(args.to_i) if args
    when 'update', 'edit'
      handle_update_command(args)
    when 'search', 'find', 's'
      @manager.search_tasks(args) unless args.empty?
    when 'stats', 'statistics'
      @manager.stats
    when 'clear'
      @manager.clear_completed
    when 'help', 'h', '?'
      show_help
    else
      puts "❓ Unknown command: #{command}. Type 'help' for available commands."
    end
  rescue => e
    puts "❌ Error: #{e.message}"
  end

  def handle_add_command(args)
    if args.empty?
      print "Task title: "
      title = gets.chomp
      
      print "Description (optional): "
      description = gets.chomp
      
      print "Priority (high/medium/low) [medium]: "
      priority = gets.chomp
      priority = 'medium' if priority.empty?
      
      print "Due date (YYYY-MM-DD HH:MM or press enter to skip): "
      due_date = gets.chomp
      due_date = nil if due_date.empty?
      
      @manager.add_task(title, description, priority, due_date)
    else
      # Quick add format: add "title" or add "title" "description"
      if args.include?('"')
        parts = args.scan(/"([^"]*)"/)
        title = parts[0] ? parts[0][0] : args
        description = parts[1] ? parts[1][0] : ''
        @manager.add_task(title, description)
      else
        @manager.add_task(args)
      end
    end
  end

  def handle_update_command(args)
    parts = args.split(' ', 2)
    id = parts[0].to_i
    
    if id == 0
      puts "❌ Please provide a valid task ID"
      return
    end

    puts "Update task #{id} (press enter to keep current value):"
    
    print "New title: "
    title = gets.chomp
    
    print "New description: "
    description = gets.chomp
    
    print "New priority (high/medium/low): "
    priority = gets.chomp
    
    print "New due date (YYYY-MM-DD HH:MM or 'none' to remove): "
    due_date = gets.chomp

    title = nil if title.empty?
    description = nil if description.empty?
    priority = nil if priority.empty?
    due_date = nil if due_date.empty?

    @manager.update_task(id, title, description, priority, due_date)
  end

  def show_help
    puts <<~HELP
      
      📚 TODO LIST MANAGER - AVAILABLE COMMANDS:
      
      📝 Task Management:
        add, a [title]           - Add a new task (interactive or quick)
        list, ls, l [filter]     - List tasks (all/pending/completed/overdue)
        complete, done, c <id>   - Mark task as completed
        uncomplete, undone, u <id> - Mark task as pending
        delete, del, d <id>      - Delete a task
        update, edit <id>        - Update task details
        
      🔍 Search & Stats:
        search, find, s <query>  - Search tasks by title/description
        stats                    - Show task statistics
        clear                    - Remove all completed tasks
        
      💡 General:
        help, h, ?               - Show this help message
        quit, exit               - Exit the application
        
      💭 Examples:
        add "Buy groceries" "Milk, bread, eggs"
        list pending
        complete 123456789
        search grocery
        update 123456789
        
      📋 Task data is automatically saved to 'tasks.json'
      
    HELP
  end
end

# Run the application
if __FILE__ == $0
  cli = TodoCLI.new
  cli.run
end
