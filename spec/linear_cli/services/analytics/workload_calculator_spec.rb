require 'spec_helper'

RSpec.describe LinearCli::Services::Analytics::WorkloadCalculator do
  let(:workload_calculator) { described_class.new }

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
            'estimate' => 5
          },
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_2', 'name' => 'Project B' },
            'assignee' => { 'id' => 'user_1', 'name' => 'John Doe' },
            'estimate' => 3
          },
          {
            'team' => { 'id' => 'team_2', 'name' => 'Design' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'assignee' => { 'id' => 'user_2', 'name' => 'Jane Smith' },
            'estimate' => 8
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
          }, # Missing team
          {
            'team' => { 'id' => 'team_1' },
            'project' => { 'id' => 'project_1' },
            'assignee' => { 'id' => 'user_1' }
          }, # Missing estimate
          {
            'team' => { 'id' => 'team_1' },
            'project' => { 'id' => 'project_1' },
            'assignee' => { 'id' => 'user_1' },
            'estimate' => 0
          } # Zero estimate
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
            'estimate' => 5
          }, # Missing project
          {
            'team' => { 'id' => 'team_1', 'name' => 'Engineering' },
            'project' => { 'id' => 'project_1', 'name' => 'Project A' },
            'estimate' => 3
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
