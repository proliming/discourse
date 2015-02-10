class Admin::DiagnosticsController < Admin::AdminController
  layout false
  skip_before_filter :check_xhr

  def memory_stats
    render text: memory_report(class_report: params.key?(:full)), content_type: Mime::TEXT
  end

  def dump_heap
    begin
      # ruby 2.1
      GC.start(full_mark: true)
      require 'objspace'

      io = File.open("discourse-heap-#{SecureRandom.hex(3)}.json",'w')
      ObjectSpace.dump_all(:output => io)
      io.close

      render text: "HEAP DUMP:\n#{io.path}", content_type: Mime::TEXT
    rescue
      render text: "HEAP DUMP:\nnot supported", content_type: Mime::TEXT
    end
  end

  protected

  def memory_report(opts={})
    begin
      # ruby 2.1
      GC.start(full_mark: true)
    rescue
      GC.start
    end


    classes = {}

    if opts[:class_report]
      ObjectSpace.each_object do |o|
        begin
          next if o == classes

          classes[o.class] ||= 0
          classes[o.class] += 1
        rescue
          # all sorts of stuff can happen here BasicObject etc.
          classes[:unknown] ||= 0
          classes[:unknown] += 1
        end
      end
      classes = classes.sort{|a,b| b[1] <=> a[1]}[0..40].map{|klass, count| "#{klass}: #{count}"}
    end

    stats = GC.stat.map{|k,v| "#{k}: #{v}"}
    counts = ObjectSpace.count_objects.sort{|a,b| b[1] <=> a[1] }.map{|k,v| "#{k}: #{v}"}



    <<TEXT
#{`hostname`.strip} pid:#{Process.pid} #{`cat /proc/#{Process.pid}/cmdline`.strip.gsub(/[^a-z1-9\/]/i, ' ')}

GC STATS:
#{stats.join("\n")}

Objects:
#{counts.join("\n")}

Process Info:
#{`cat /proc/#{Process.pid}/status`}

Classes:
#{classes.length > 0 ? classes.join("\n") : "Class report omitted use ?full=1 to include it"}

TEXT

  end
end
