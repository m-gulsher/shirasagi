module Gws::Schedule::PlanHelper
  def term(item)
    format = item.allday? ? "%Y/%m/%d" : "%Y/%m/%d %H:%M"
    times = [item.start_at.strftime(format)]
    times << item.end_at.strftime(format) if item.end_at.present?
    times.uniq.join(" - ")
  end

  def calendar_format(events, opts = {})
    events = events.map do |p|
      data = { id: p.id, title: h(p.name), start: p.start_at, end: p.end_at, allDay: p.allday? }
      data.merge!(backgroundColor: c.bg_color, borderColor: c.bg_color, textColor: c.text_color) if c = p.category
      data
    end

    if opts[:holiday]
      events += HolidayJapan.between(opts[:holiday][0], opts[:holiday][1]).map do |d, name|
        { className: 'fc-holiday', title: name, start: d, allDay: true, editable: false }
      end
    end

    events
  end

  def calendar_accessor_js
    %(
      $('.calendar-accessor .fc-prev-button').click(function(){ $('.calendar.multiple .fc-prev-button').click(); });
      $('.calendar-accessor .fc-next-button').click(function(){ $('.calendar.multiple .fc-next-button').click(); });
    ).strip.html_safe
  end

  def calendar_default_options_js
    %(
      lang: 'ja',
      timeFormat: 'HH:mm',
      columnFormat: { month: 'ddd', week: 'M/D（ddd）', day: 'M/D（ddd）' },
      fixedWeekCount: false,
      startParam: 's[start]',
      endParam: 's[end]'
    ).strip.html_safe
  end

  def calendar_editable_options_js(opts = {})
    url = opts[:url] || url_for(action: :index)

    %(
      editable: true,
      loading: function(isLoading, view) {
      },
      eventClick: function(event, jsEvent, view) {
        if ($(this).hasClass('fc-holiday')) return false;
        location.href = '#{url}/' + event.id;
      },
      eventDrop: function(event, delta, revertFunc) {
        var start = event.start.format();
        var end = (event.end == null) ? null : event.end.format();
        $.ajax({
          type: 'PUT',
          url: '#{url}/' + event.id + ".json",
          data: { item: { start_at: start, end_at: end } },
          error: function(xhr, status, error) {
            revertFunc();
          }
        });
      },
      eventResize: function(event, delta, revertFunc) {
        $.ajax({
          type: 'PUT',
          url: '#{url}/' + event.id + ".json",
          data: { item: { start_at: event.start.format(), end_at: event.end.format() } },
          error: function() { revertFunc(); }
        });
      }
    ).strip.html_safe
  end
end
