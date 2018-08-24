SS_Workflow = function (el, options) {
  this.$el = $(el);
  this.options = options;

  var pThis = this;

  this.$el.on("click", ".update-item", function (e) {
    pThis.updateItem($(this));
    e.preventDefault();
    return false;
  });

  $(document).on("click", ".mod-workflow-approve .update-item", function (e) {
    pThis.updateItem($(this));
    e.preventDefault();
    return false;
  });

  $(document).on("click", ".mod-workflow-view .request-cancel", function (e) {
    pThis.cancelRequest($(this));
    e.preventDefault();
    return false;
  });

  this.$el.find(".mod-workflow-approve").insertBefore("#addon-basic");

  this.$el.find(".toggle-label").on("click", function (e) {
    pThis.$el.find(".request-setting").slideToggle();
    e.preventDefault();
    return false;
  });

  this.$el.find(".workflow-partial-section").each(function() {
    pThis.loadRouteList();
  });

  this.$el.on("click", ".workflow-route-start", function (e) {
    var routeId = $(this).siblings('#workflow_route:first').val();
    pThis.loadRoute(routeId);
    e.preventDefault();
    return false;
  });

  this.$el.on("click", ".workflow-route-cacnel", function (e) {
    pThis.loadRouteList();
    e.preventDefault();
    return false;
  });

  this.$el.on("click", ".workflow-reroute", function (e) {
    var $this = $(this);
    var level = $this.data('level');
    var userId = $this.data('user-id');

    pThis.reroute(level, userId);
    e.preventDefault();
    return false;
  });

  this.$el.on("click", "button[name=set_seen]", function (e) {
    var $this = $(this);
    var userId = $this.data('user-id');
    pThis.setSeen(userId);
    e.preventDefault();
    return false;
  });
};

SS_Workflow.prototype = {
  collectApprovers: function() {
    var approvers = [];

    this.$el.find(".workflow-multi-select").each(function () {
      approvers = approvers.concat($(this).val());
    });
    this.$el.find("input[name='workflow_approvers']").each(function() {
      approvers.push($(this).prop("value"));
    });

    return approvers;
  },
  collectCirculations: function() {
    var circulations = [];

    this.$el.find("input[name='workflow_circulations']").each(function() {
      circulations.push($(this).prop("value"));
    });

    return circulations;
  },
  composeWorkflowUrl: function(type) {
    var uri = location.pathname.split("/");
    uri[2] = this.options.workflow_node;
    uri[3] = type;
    if (uri.length > 5) {
      uri.splice(4, 1);
    }

    return uri.join("/");
  },
  updateItem: function($this) {
    var updatetype = $this.attr("updatetype");
    var approvers = this.collectApprovers();
    if ($.isEmptyObject(approvers) && updatetype === "request") {
      alert(this.options.errors.not_select);
      return;
    }

    var required_counts = [];
    this.$el.find("input[name='workflow_required_counts']").each(function() {
      required_counts.push($(this).prop("value"));
    });

    var uri = this.composeWorkflowUrl('pages');
    uri += "/" + updatetype + "_update";
    var workflow_comment = $("#workflow_comment").prop("value");
    var workflow_pull_up = $("#workflow_pull_up").prop("value");
    var workflow_on_remand = $("#workflow_on_remand").prop("value");
    var redirect_location = this.options.redirect_location;
    var remand_comment = $("#remand_comment").prop("value");
    var forced_update_option;
    if (updatetype == "request") {
      forced_update_option = $("#forced-request").prop("checked");
    } else {
      forced_update_option = $("#forced-update").prop("checked");
    }
    var circulations = this.collectCirculations();
    $.ajax({
      type: "POST",
      url: uri,
      async: false,
      data: {
        workflow_comment: workflow_comment,
        workflow_pull_up: workflow_pull_up,
        workflow_on_remand: workflow_on_remand,
        workflow_approvers: approvers,
        workflow_required_counts: required_counts,
        remand_comment: remand_comment,
        url: this.options.request_url,
        forced_update_option: forced_update_option,
        workflow_circulations: circulations
      },
      success: function (data) {
        if (data["workflow_alert"]) {
          alert(data["workflow_alert"]);
          return;
        }
        if (data["workflow_state"] === "approve" && redirect_location !== "") {
          location.href = redirect_location;
        } else {
          location.reload();
        }
      },
      error: function(xhr, status) {
        try {
          var errors = $.parseJSON(xhr.responseText);
          alert(["== Error =="].concat(errors).join("\n"));
        }
        catch (ex) {
          alert(["== Error =="].concat(xhr["statusText"]).join("\n"));
        }
      }
    });
  },
  cancelRequest: function($this) {
    var confirmation = $this.data('ss-confirmation');
    if (confirmation) {
      if (!confirm(confirmation)) {
        return false;
      }
    }

    var method = $this.data('ss-method') || 'post';
    var action = $this.attr('href');
    var csrfToken = $('meta[name="csrf-token"]').attr('content');

    $.ajax({
      type: method,
      url: action,
      async: false,
      data: {
        authenticity_token: csrfToken
      },
      success: function (data) {
        if (data["workflow_alert"]) {
          alert(data["workflow_alert"]);
          return;
        }
        if (data["workflow_state"] === "approve" && redirect_location !== "") {
          location.href = redirect_location;
        } else {
          location.reload();
        }
      },
      error: function(xhr, status) {
        try {
          var errors = $.parseJSON(xhr.responseText);
          alert(["== Error =="].concat(errors).join("\n"));
        }
        catch (ex) {
          alert(["== Error =="].concat(xhr["statusText"]).join("\n"));
        }
      }
    });
  },
  loadRouteList: function() {
    var pThis = this;
    var uri = this.composeWorkflowUrl('wizard');
    $.ajax({
      type: "GET",
      url: uri,
      async: false,
      success: function(html, status) {
        pThis.$el.find(".workflow-partial-section").html(html);
      },
      error: function(xhr, status) {
        try {
          var errors = $.parseJSON(xhr.responseText);
          alert(["== Error =="].concat(errors).join("\n"));
        } catch(ex) {
          alert(["== Error =="].concat(xhr["statusText"]).join("\n"));
        }
      }
    });
  },
  loadRoute: function(routeId) {
    var pThis = this;
    var uri = this.composeWorkflowUrl('wizard');
    uri += "/approver_setting";
    var data = { route_id: routeId };
    $.ajax({
      type: "POST",
      url: uri,
      async: false,
      data: data,
      success: function(html, status) {
        pThis.$el.find(".workflow-partial-section").html(html);
      },
      error: function(xhr, status) {
        try {
          var errors = $.parseJSON(xhr.responseText);
          alert(errors.join("\n"));
        } catch (ex) {
          alert(["== Error =="].concat(xhr["statusText"]).join("\n"));
        }
      }
    });
  },
  reroute: function(level, userId) {
    var uri = this.composeWorkflowUrl('wizard');
    uri += "/reroute";
    var param = $.param({ level: level, user_id: userId });
    uri += "?" + param;

    var pThis = this;
    $('<a/>').attr('href', uri).colorbox({
      fixed: true,
      width: "90%",
      height: "90%",
      open: true,
      onCleanup: function() {
        var selectedUserId = $('#cboxLoadedContent input[name=selected_user_id]').val();
        if (! selectedUserId) {
          return;
        }

        var uri = pThis.composeWorkflowUrl('wizard');
        uri += "/reroute";
        var data = {
          level: level, user_id: userId, new_user_id: selectedUserId, url: pThis.options.request_url
        };

        $.ajax({
          type: 'POST',
          url: uri,
          data: data,
          success: function(html, status) {
            location.reload();
          },
          error: function(xhr, status) {
            try {
              var errors = $.parseJSON(xhr.responseText);
              alert(errors.join("\n"));
            } catch (ex) {
              alert(["== Error =="].concat(xhr["statusText"]).join("\n"));
            }
          }
        });
      }
    });
  },
  setSeen: function(userId) {
    var uri = this.composeWorkflowUrl('wizard');
    uri += "/circulation";
    uri += "?redirect_to=" + encodeURIComponent(location.href);

    var pThis = this;
    $('<a/>').attr('href', uri).colorbox({
      maxWidth: "80%",
      maxHeight: "80%",
      fixed: true,
      open: true,
      onCleanup: function() {
      }
    });
  }
};

SS_WorkflowRerouteBox = function (el, options) {
  this.$el = $(el);
  this.options = options;

  var pThis = this;

  this.$el.find('form.search').on("submit", function(e) {
    $(this).ajaxSubmit({
      url: $(this).attr("action"),
      success: function (data) {
        pThis.$el.closest("#cboxLoadedContent").html(data);
      },
      error: function (data, status) {
        alert("== Error ==");
      }
    });

    e.preventDefault();
  });

  this.$el.find('.pagination a').on("click", function(e) {
    var url = $(this).attr("href");
    pThis.$el.closest("#cboxLoadedContent").load(url, function(response, status, xhr) {
      if (status === 'error') {
        alert("== Error ==");
      }
    });

    e.preventDefault();
    return false;
  });

  this.$el.find('.select-single-item').on("click", function(e) {
    var $this = $(this);
    if (! SS.disableClick($this)) {
      return false;
    }

    pThis.selectItem($this);

    e.preventDefault();
    $.colorbox.close();
  });
};

SS_WorkflowRerouteBox.prototype = {
  selectItem: function($this) {
    var listItem = $this.closest('.list-item');
    var id = listItem.data('id');
    var name = listItem.data('name');
    var email = listItem.data('email');

    var source_name = this.$el.data('name');
    var source_email = this.$el.data('email');

    if (source_name) {
      if (source_email) {
        source_name += '(' + source_email + ')'
      }
    }

    var message = '';
    if (source_name) {
      message += source_name;
      message += 'を';
    }
    message += name + '(' + email + ')' + 'に変更します。よろしいですか？';
    if(! confirm(message)) {
      return;
    }

    this.$el.find('input[name=selected_user_id]').val(id);
  }
};
