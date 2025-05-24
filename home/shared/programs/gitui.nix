{...}: {
  programs.gitui = {
    enable = true;
    theme = ''
      (
          selected_tab: Some("Reset"),
          command_fg: Some("#c5c9c5"),
          selection_bg: Some("#2d4f67"),
          selection_fg: Some("#c8c093"),
          cmdbar_bg: Some("#2d4f67"),
          cmdbar_extra_lines_bg: Some("#181616"),
          disabled_fg: Some("#a6a69c"),
          diff_line_add: Some("#87a987"),
          diff_line_delete: Some("#e46876"),
          diff_file_added: Some("#87a987"),
          diff_file_removed: Some("#e46876"),
          diff_file_moved: Some("#938aa9"),
          diff_file_modified: Some("#e6c384"),
          commit_hash: Some("#7fb4ca"),
          commit_time: Some("#c8c093"),
          commit_author: Some("#7aa89f"),
          danger_fg: Some("#e46876"),
          push_gauge_bg: Some("#8ba4b0"),
          push_gauge_fg: Some("#181616"),
          tag_fg: Some("#a292a3"),
          branch_fg: Some("#8ea4a2"),
      )
    '';
  };
}
