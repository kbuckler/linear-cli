# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::Services::Analytics::WorkloadCalculator do
  let(:workload_calculator) { described_class.new }

  describe '#calculate_team_project_workload' do
    let(:team) do
      {
        'id' => 'team_1',
        'name' => 'Engineering'
      }
    end

    let(:projects) do
      [
        {
          'id' => 'project_1',
          'name' => 'Project A',
          'teams' => {
            'nodes' => [
              { 'id' => 'team_1', 'name' => 'Engineering' }
            ]
          }
        },
        {
          'id' => 'project_2',
          'name' => 'Project B',
          'teams' => {
            'nodes' => [
              { 'id' => 'team_1', 'name' => 'Engineering' }
            ]
          }
        }
      ]
    end

    context 'when issues is nil' do
      it 'handles nil issues gracefully' do
        result = workload_calculator.calculate_team_project_workload(nil, team, projects)

        expect(result).to be_a(Hash)
        expect(result[:id]).to eq('team_1')
        expect(result[:name]).to eq('Engineering')
        expect(result[:projects]).to be_empty
        expect(result[:contributors]).to be_empty
      end
    end

    context 'when issues is empty' do
      it 'handles empty issues array' do
        result = workload_calculator.calculate_team_project_workload([], team, projects)

        expect(result).to be_a(Hash)
        expect(result[:id]).to eq('team_1')
        expect(result[:name]).to eq('Engineering')
        expect(result[:projects]).to be_empty
        expect(result[:contributors]).to be_empty
      end
    end

    context 'when issues have valid data' do
      let(:issues) do
        [
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 5,
            'completedAt' => '2023-01-01'
          },
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_2', 'name' => 'Project B' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 3,
            'completedAt' => '2023-01-02'
          },
          {
            'team' => { 'id' => 'team_2', 'name' => 'Design' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_2', 'name' => 'Jane Smith' },
            'estimate' => 8,
            'completedAt' => '2023-01-03'
          }
        ]
      end

      it 'processes issues correctly for the target team' do
        result = workload_calculator.calculate_team_project_workload(issues, team, projects)

        expect(result).to be_a(Hash)
        expect(result[:id]).to eq('team_1')
        expect(result[:name]).to eq('Engineering')

        # Check project structure
        expect(result[:projects]).to have_key('project_1')
        expect(result[:projects]).to have_key('project_2')

        # Check contributor data
        expect(result[:contributors]).to have_key('user_1')
        expect(result[:contributors]['user_1'][:name]).to eq('John Doe')
        expect(result[:contributors]['user_1'][:total_points]).to eq(8) # 5 + 3
        expect(result[:contributors]['user_1'][:issues_count]).to eq(2) # 2 issues

        # Check project data
        project1 = result[:projects]['project_1']
        expect(project1[:name]).to eq('Project A')
        expect(project1[:total_points]).to eq(5)
        expect(project1[:issues_count]).to eq(1) # 1 issue
        expect(project1[:contributors]).to have_key('user_1')
        expect(project1[:contributors]['user_1'][:issues_count]).to eq(1) # 1 issue

        # Check percentage calculations
        expect(result[:contributors]['user_1'][:projects]['project_1'][:percentage]).to eq(62.5) # 5/8 * 100
        expect(result[:contributors]['user_1'][:projects]['project_2'][:percentage]).to eq(37.5) # 3/8 * 100

        # Check issue counts in project/contributor relationships
        expect(result[:contributors]['user_1'][:projects]['project_1'][:issues_count]).to eq(1) # 1 issue
        expect(result[:contributors]['user_1'][:projects]['project_2'][:issues_count]).to eq(1) # 1 issue
      end

      it 'filters out issues from other teams' do
        result = workload_calculator.calculate_team_project_workload(issues, team, projects)

        # Should not include user_2 as they're on team_2
        expect(result[:contributors]).not_to have_key('user_2')
      end
    end

    context 'when issues have missing project or assignee' do
      let(:issues) do
        [
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 5,
            'completedAt' => '2023-01-01'
          }, # Missing project
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'estimate' => 3,
            'completedAt' => '2023-01-02'
          } # Missing assignee
        ]
      end

      it 'handles missing project by using no_project' do
        result = workload_calculator.calculate_team_project_workload(issues, team, projects)

        expect(result[:projects]).to have_key('no_project')
        expect(result[:projects]['no_project'][:name]).to eq('No Project')
        expect(result[:projects]['no_project'][:total_points]).to eq(5)
      end

      it 'handles missing assignee by using unassigned' do
        result = workload_calculator.calculate_team_project_workload(issues, team, projects)

        expect(result[:contributors]).to have_key('unassigned')
        expect(result[:contributors]['unassigned'][:name]).to eq('Unassigned')
        expect(result[:contributors]['unassigned'][:total_points]).to eq(3)
      end
    end

    context 'when issues have zero estimates' do
      let(:issues) do
        [
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 0, # Zero estimate
            'completedAt' => '2023-01-01'
          },
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => nil, # Nil estimate
            'completedAt' => '2023-01-02'
          }
        ]
      end

      it 'treats zero and nil estimates as 1 point of effort' do
        result = workload_calculator.calculate_team_project_workload(issues, team, projects)

        # Both issues should be counted as 1 point each
        expect(result[:projects]['project_1'][:total_points]).to eq(2)
        expect(result[:contributors]['user_1'][:total_points]).to eq(2)
      end

      it 'correctly tracks issue counts despite zero estimates' do
        result = workload_calculator.calculate_team_project_workload(issues, team, projects)

        # Should count 2 issues total
        expect(result[:projects]['project_1'][:issues_count]).to eq(2)
        expect(result[:contributors]['user_1'][:issues_count]).to eq(2)
      end
    end

    context 'when multiple contributors work on multiple projects' do
      let(:issues) do
        [
          # User 1 on Project 1
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 3,
            'completedAt' => '2023-01-01'
          },
          # User 1 on Project 1 (another issue)
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 2,
            'completedAt' => '2023-01-02'
          },
          # User 2 on Project 1
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_2', 'name' => 'Jane Smith' },
            'estimate' => 5,
            'completedAt' => '2023-01-03'
          },
          # User 1 on Project 2
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_2', 'name' => 'Project B' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 8,
            'completedAt' => '2023-01-04'
          }
        ]
      end

      it 'correctly tracks issue counts per contributor and project' do
        result = workload_calculator.calculate_team_project_workload(issues, team, projects)

        # Project issue counts
        expect(result[:projects]['project_1'][:issues_count]).to eq(3) # 2 from user_1, 1 from user_2
        expect(result[:projects]['project_2'][:issues_count]).to eq(1) # 1 from user_1

        # Contributor issue counts
        expect(result[:contributors]['user_1'][:issues_count]).to eq(3) # 2 on project_1, 1 on project_2
        expect(result[:contributors]['user_2'][:issues_count]).to eq(1) # 1 on project_1

        # Project-contributor relationship issue counts
        expect(result[:projects]['project_1'][:contributors]['user_1'][:issues_count]).to eq(2)
        expect(result[:projects]['project_1'][:contributors]['user_2'][:issues_count]).to eq(1)
        expect(result[:projects]['project_2'][:contributors]['user_1'][:issues_count]).to eq(1)

        # Contributor-project relationship issue counts
        expect(result[:contributors]['user_1'][:projects]['project_1'][:issues_count]).to eq(2)
        expect(result[:contributors]['user_1'][:projects]['project_2'][:issues_count]).to eq(1)
        expect(result[:contributors]['user_2'][:projects]['project_1'][:issues_count]).to eq(1)
      end

      it 'calculates the correct point totals' do
        result = workload_calculator.calculate_team_project_workload(issues, team, projects)

        # Project point totals
        expect(result[:projects]['project_1'][:total_points]).to eq(10) # 3+2 from user_1, 5 from user_2
        expect(result[:projects]['project_2'][:total_points]).to eq(8)  # 8 from user_1

        # Contributor point totals
        expect(result[:contributors]['user_1'][:total_points]).to eq(13) # 3+2 on project_1, 8 on project_2
        expect(result[:contributors]['user_2'][:total_points]).to eq(5)  # 5 on project_1
      end
    end
  end

  describe '#calculate_engineer_project_workload' do
    let(:teams) do
      [
        {
          'id' => 'team_1',
          'name' => 'Engineering'
        },
        {
          'id' => 'team_2',
          'name' => 'Design'
        }
      ]
    end

    let(:projects) do
      [
        {
          'id' => 'project_1',
          'name' => 'Project A'
        },
        {
          'id' => 'project_2',
          'name' => 'Project B'
        }
      ]
    end

    context 'when issues is nil' do
      it 'handles nil issues gracefully' do
        result = workload_calculator.calculate_engineer_project_workload(nil, teams, projects)

        expect(result).to be_a(Hash)
        expect(result).to have_key('team_1')
        expect(result).to have_key('team_2')
        expect(result['team_1'][:engineers]).to be_empty
        expect(result['team_1'][:projects]).to be_empty
      end
    end

    context 'when issues is empty' do
      it 'handles empty issues array' do
        result = workload_calculator.calculate_engineer_project_workload([], teams, projects)

        expect(result).to be_a(Hash)
        expect(result).to have_key('team_1')
        expect(result).to have_key('team_2')
        expect(result['team_1'][:engineers]).to be_empty
        expect(result['team_1'][:projects]).to be_empty
      end
    end

    context 'when issues have valid data' do
      let(:issues) do
        [
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 5,
            'completedAt' => '2023-01-01'
          },
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_2', 'name' => 'Project B' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 3,
            'completedAt' => '2023-01-02'
          },
          {
            'team' => { 'id' => 'team_2', 'name' => 'Design' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_2', 'name' => 'Jane Smith' },
            'estimate' => 8,
            'completedAt' => '2023-01-03'
          }
        ]
      end

      it 'processes issues correctly' do
        result = workload_calculator.calculate_engineer_project_workload(issues, teams, projects)

        expect(result).to be_a(Hash)
        expect(result).to have_key('team_1')
        expect(result).to have_key('team_2')

        # Check team 1 structure
        team1 = result['team_1']
        expect(team1[:name]).to eq('Engineering')
        expect(team1[:projects]).to have_key('project_1')
        expect(team1[:projects]).to have_key('project_2')
        expect(team1[:engineers]).to have_key('user_1')

        # Check project data
        project1 = team1[:projects]['project_1']
        expect(project1[:name]).to eq('Project A')
        expect(project1[:total_points]).to eq(5)
        expect(project1[:engineers]).to have_key('user_1')

        # Check engineer data
        engineer1 = team1[:engineers]['user_1']
        expect(engineer1[:name]).to eq('John Doe')
        expect(engineer1[:total_points]).to eq(8) # 5 + 3
        expect(engineer1[:projects]).to have_key('project_1')
        expect(engineer1[:projects]).to have_key('project_2')

        # Check percentage calculations
        expect(engineer1[:projects]['project_1'][:percentage]).to eq(62.5) # 5/8 * 100
        expect(engineer1[:projects]['project_2'][:percentage]).to eq(37.5) # 3/8 * 100
      end
    end

    context 'when issues have missing team or estimate' do
      let(:incomplete_issues) do
        [
          {
            'project' => { 'id' => 'project_1' },
            'assignee' => { 'id' => 'user_1' }
            # Missing team and no completedAt
          },
          {
            'team' => { 'id' => 'team_1' }
            # Missing project, assignee, estimate and completedAt
          },
          {
            'team' => { 'id' => 'team_1' },
            'project' => { 'id' => 'project_1' },
            'assignee' => { 'id' => 'user_1' },
            'estimate' => 0
            # Missing completedAt
          }
        ]
      end

      it 'skips issues with missing required fields' do
        result = workload_calculator.calculate_engineer_project_workload(incomplete_issues, teams, projects)

        expect(result).to be_a(Hash)
        expect(result).to have_key('team_1')
        expect(result['team_1'][:engineers]).to be_empty
        expect(result['team_1'][:projects]).to be_empty
      end
    end

    context 'with issues missing project or assignee' do
      let(:issues) do
        [
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 5,
            'completedAt' => '2023-01-01'
          }, # Missing project
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'estimate' => 3,
            'completedAt' => '2023-01-02'
          } # Missing assignee
        ]
      end

      it 'handles missing project by using no_project' do
        result = workload_calculator.calculate_engineer_project_workload(issues, teams, projects)

        expect(result['team_1'][:projects]).to have_key('no_project')
        expect(result['team_1'][:projects]['no_project'][:name]).to eq('No Project')
        expect(result['team_1'][:projects]['no_project'][:total_points]).to eq(5)
      end

      it 'handles missing assignee by using unassigned' do
        result = workload_calculator.calculate_engineer_project_workload(issues, teams, projects)

        expect(result['team_1'][:engineers]).to have_key('unassigned')
        expect(result['team_1'][:engineers]['unassigned'][:name]).to eq('Unassigned')
        expect(result['team_1'][:engineers]['unassigned'][:total_points]).to eq(3)
      end
    end
  end

  describe '#calculate_percentage' do
    it 'calculates percentage correctly' do
      percentage = workload_calculator.send(:calculate_percentage, 5, 10)
      expect(percentage).to eq(50.0)
    end

    it 'handles zero denominator gracefully' do
      percentage = workload_calculator.send(:calculate_percentage, 5, 0)
      expect(percentage).to eq(0.0)
    end

    it 'rounds to 2 decimal places' do
      percentage = workload_calculator.send(:calculate_percentage, 1, 3)
      expect(percentage).to eq(33.33)
    end
  end
end
