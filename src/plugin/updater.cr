class Plugin
  class Updater
    use_default

    def initialize
      interval = Config.current.plugin_update_interval_hours
      return if interval <= 0
      spawn do
        loop do
          Plugin.list.map(&.["id"]).each do |pid|
            check_updates pid
          end
          sleep interval.hours
        end
      end
    end

    def check_updates(plugin_id : String)
      Logger.debug "Checking plugin #{plugin_id} for updates"

      plugin = Plugin.new plugin_id
      if plugin.info.version == 1
        Logger.debug "Plugin #{plugin_id} is targeting API version 1. " \
                     "Skipping update check"
        return
      end

      subscriptions = plugin.list_subscriptions_raw
      subscriptions.each do |sub|
        check_subscription plugin, sub
      end
      subscriptions.save
    rescue e
      Logger.error "Error checking plugin #{plugin_id} for updates: " \
                   "#{e.message}"
    end

    def check_subscription(plugin : Plugin, sub : Subscription)
      Logger.debug "Checking subscription #{sub.name} for updates"
      matches = plugin.new_chapters(sub.manga_id, sub.last_checked)
        .as_a.select do |chapter|
        sub.match_chapter chapter
      end
      if matches.empty?
        Logger.debug "No new chapters found."
        sub.last_checked = Time.utc.to_unix
        return
      end
      Logger.debug "Found #{matches.size} new chapters. " \
                   "Pushing to download queue"
      jobs = matches.map { |ch|
        Queue::Job.new(
          "#{plugin.info.id}-#{Base64.encode ch["id"].as_s}",
          "", # manga_id
          ch["title"].as_s,
          sub.manga_title,
          Queue::JobStatus::Pending,
          Time.utc
        )
      }
      inserted_count = Queue.default.push jobs
      Logger.info "#{inserted_count}/#{matches.size} new chapters added " \
                  "to the download queue. Plugin ID #{plugin.info.id}, " \
                  "subscription name #{sub.name}"
      if inserted_count != matches.size
        Logger.error "Failed to add #{matches.size - inserted_count} " \
                     "chapters to download queue"
      end
      sub.last_checked = Time.utc.to_unix
    rescue e
      Logger.error "Error when checking updates for subscription " \
                   "#{sub.name}: #{e.message}"
    end
  end
end
