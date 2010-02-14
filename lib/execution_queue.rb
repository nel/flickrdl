require 'observer'
class ExecutionQueue
  include Observable
  
  class Observer
    def initialize(execution_queue)
      @execution_queue = execution_queue
      @execution_queue.add_observer(self)
    end
    
    def update(method, *args)
      if respond_to?(method)
        send(method, *args)
      end
    end
  end
  
  class ThreadWorker
    def initialize(execution_queue)
      @thread = Thread.new do
        loop do
          if task = execution_queue.next
            @active = true
            task.call
            execution_queue.send :notify, :done
          else
            @active = false
            sleep 0.01
          end
        end
      end
    end

    def inactive?
      !@active
    end
    
    def exit
      @thread.exit
    end
  end
  
  def initialize(thread_pool_size = 10)
    @mutex = Mutex.new
    @queue = []
    @workers = []
    thread_pool_size.times { @workers << ThreadWorker.new(self) }
  end
  
  def sync &block
    @mutex.synchronize &block
  end
  
  def next
    sync do
      notify(:next) unless @queue.empty?
      @queue.shift
    end
  end
  
  def enqueue &block
    sync do
      notify :enqueue
      @queue << block
    end
  end
  
  def exit
    @workers.map &:exit
  end
  
  def wait_for_completion
    sleep 0.01 until @queue.empty? && @workers.all?(&:inactive?) #there is a tiny possible race condition with inactive?
  end 
  
private
  def notify(sym, *args)
    changed
    notify_observers(sym, *args)
  end
end