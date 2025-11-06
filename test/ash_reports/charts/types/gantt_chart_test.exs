defmodule AshReports.Charts.Types.GanttChartTest do
  use ExUnit.Case, async: true

  alias AshReports.Charts.Types.GanttChart

  describe "build/2" do
    test "builds gantt chart with valid datetime data" do
      data = [
        %{
          category: "Phase 1",
          task: "Design",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-15 00:00:00]
        },
        %{
          category: "Phase 1",
          task: "Development",
          start_time: ~N[2024-01-10 00:00:00],
          end_time: ~N[2024-02-01 00:00:00]
        }
      ]

      config = %{title: "Project Timeline"}

      chart = GanttChart.build(data, config)

      assert %Contex.GanttChart{} = chart
      assert chart.dataset
    end

    test "builds gantt chart with task_id" do
      data = [
        %{
          category: "Dev",
          task: "Feature A",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-15 00:00:00],
          task_id: "task_1"
        },
        %{
          category: "Dev",
          task: "Feature B",
          start_time: ~N[2024-01-10 00:00:00],
          end_time: ~N[2024-01-25 00:00:00],
          task_id: "task_2"
        }
      ]

      config = %{}

      chart = GanttChart.build(data, config)

      assert %Contex.GanttChart{} = chart
    end

    test "builds gantt chart with string keys" do
      data = [
        %{
          "category" => "Testing",
          "task" => "Unit Tests",
          "start_time" => ~N[2024-01-01 00:00:00],
          "end_time" => ~N[2024-01-10 00:00:00]
        }
      ]

      config = %{}

      chart = GanttChart.build(data, config)

      assert %Contex.GanttChart{} = chart
    end

    test "applies custom width and height" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-15 00:00:00]
        }
      ]

      config = %{width: 1000, height: 600}

      chart = GanttChart.build(data, config)

      assert chart.options[:width] == 1000
      assert chart.options[:height] == 600
    end

    test "applies custom colors" do
      data = [
        %{
          category: "Phase 1",
          task: "Task A",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-10 00:00:00]
        },
        %{
          category: "Phase 2",
          task: "Task B",
          start_time: ~N[2024-01-05 00:00:00],
          end_time: ~N[2024-01-15 00:00:00]
        }
      ]

      config = %{colours: ["#ff6384", "#36a2eb", "#ffce56"]}

      chart = GanttChart.build(data, config)

      assert chart.options[:colour_palette] == ["ff6384", "36a2eb", "ffce56"]
    end

    test "uses default options from Contex" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-10 00:00:00]
        }
      ]

      config = %{}

      chart = GanttChart.build(data, config)

      # Contex will use its defaults for padding and show_task_labels
      assert %Contex.GanttChart{} = chart
    end

    test "uses default color palette when no colors specified" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-10 00:00:00]
        }
      ]

      config = %{}

      chart = GanttChart.build(data, config)

      assert chart.options[:colour_palette] == :default
    end
  end

  describe "validate/1" do
    test "validates correct NaiveDateTime data" do
      data = [
        %{
          category: "Phase 1",
          task: "Task A",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-15 00:00:00]
        },
        %{
          category: "Phase 2",
          task: "Task B",
          start_time: ~N[2024-01-10 00:00:00],
          end_time: ~N[2024-01-25 00:00:00]
        }
      ]

      assert :ok = GanttChart.validate(data)
    end

    test "validates correct DateTime data" do
      data = [
        %{
          category: "Dev",
          task: "Feature",
          start_time: DateTime.from_naive!(~N[2024-01-01 00:00:00], "Etc/UTC"),
          end_time: DateTime.from_naive!(~N[2024-01-15 00:00:00], "Etc/UTC")
        }
      ]

      assert :ok = GanttChart.validate(data)
    end

    test "validates mixed NaiveDateTime and DateTime" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: DateTime.from_naive!(~N[2024-01-15 00:00:00], "Etc/UTC")
        }
      ]

      assert :ok = GanttChart.validate(data)
    end

    test "validates data with task_id" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-10 00:00:00],
          task_id: "task_1"
        }
      ]

      assert :ok = GanttChart.validate(data)
    end

    test "validates data with string keys" do
      data = [
        %{
          "category" => "Testing",
          "task" => "Unit Tests",
          "start_time" => ~N[2024-01-01 00:00:00],
          "end_time" => ~N[2024-01-10 00:00:00]
        }
      ]

      assert :ok = GanttChart.validate(data)
    end

    test "rejects empty data" do
      assert {:error, "Data cannot be empty"} = GanttChart.validate([])
    end

    test "rejects non-list data" do
      data = %{category: "Dev", task: "Task 1"}

      assert {:error, "Data must be a list"} = GanttChart.validate(data)
    end

    test "rejects data with missing category field" do
      data = [
        %{
          task: "Task 1",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-10 00:00:00]
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      assert String.contains?(message, "must have category, task, start_time, and end_time")
    end

    test "rejects data with missing task field" do
      data = [
        %{
          category: "Dev",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-10 00:00:00]
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      assert String.contains?(message, "must have category, task, start_time, and end_time")
    end

    test "rejects data with missing start_time field" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          end_time: ~N[2024-01-10 00:00:00]
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      assert String.contains?(message, "must have category, task, start_time, and end_time")
    end

    test "rejects data with missing end_time field" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: ~N[2024-01-01 00:00:00]
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      assert String.contains?(message, "must have category, task, start_time, and end_time")
    end

    test "rejects string dates (not auto-converted)" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: "2024-01-01",
          end_time: "2024-01-10"
        }
      ]

      assert {:error, message} = GanttChart.validate(data)

      assert String.contains?(
               message,
               "start_time and end_time must be NaiveDateTime or DateTime"
            )
    end

    test "rejects non-datetime types" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: 1234567890,
          end_time: 1234567900
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      assert String.contains?(message, "must be NaiveDateTime or DateTime")
    end

    test "rejects when start_time is after end_time" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: ~N[2024-01-15 00:00:00],
          end_time: ~N[2024-01-01 00:00:00]
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      assert String.contains?(message, "start_time must be before end_time")
    end

    test "rejects when start_time equals end_time" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-01 00:00:00]
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      assert String.contains?(message, "start_time must be before end_time")
    end

    test "reports error with item index for debugging" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-10 00:00:00]
        },
        %{
          category: "Dev",
          task: "Task 2",
          start_time: "invalid",
          end_time: ~N[2024-01-15 00:00:00]
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      assert String.contains?(message, "Item 2")
    end

    test "validates first error found and stops" do
      data = [
        %{
          category: "Dev",
          task: "Task 1",
          start_time: "invalid1",
          end_time: ~N[2024-01-10 00:00:00]
        },
        %{
          category: "Dev",
          task: "Task 2",
          start_time: "invalid2",
          end_time: ~N[2024-01-15 00:00:00]
        }
      ]

      assert {:error, message} = GanttChart.validate(data)
      # Should report first error (Item 1)
      assert String.contains?(message, "Item 1")
    end
  end

  describe "project timeline scenarios" do
    test "handles multi-phase project with overlapping tasks" do
      data = [
        %{
          category: "Planning",
          task: "Requirements",
          start_time: ~N[2024-01-01 00:00:00],
          end_time: ~N[2024-01-10 00:00:00]
        },
        %{
          category: "Planning",
          task: "Design",
          start_time: ~N[2024-01-08 00:00:00],
          end_time: ~N[2024-01-20 00:00:00]
        },
        %{
          category: "Development",
          task: "Backend",
          start_time: ~N[2024-01-15 00:00:00],
          end_time: ~N[2024-02-15 00:00:00]
        },
        %{
          category: "Development",
          task: "Frontend",
          start_time: ~N[2024-01-22 00:00:00],
          end_time: ~N[2024-02-20 00:00:00]
        },
        %{
          category: "Testing",
          task: "QA",
          start_time: ~N[2024-02-10 00:00:00],
          end_time: ~N[2024-02-28 00:00:00]
        }
      ]

      assert :ok = GanttChart.validate(data)

      config = %{
        title: "Project Timeline",
        width: 1000,
        height: 500,
        colors: ["e3f2fd", "bbdefb", "90caf9"]
      }

      chart = GanttChart.build(data, config)

      assert %Contex.GanttChart{} = chart
      assert chart.dataset.data == data
    end
  end
end
