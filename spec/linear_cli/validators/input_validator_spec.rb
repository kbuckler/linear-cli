# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LinearCli::Validators::InputValidator do
  describe '.validate_issue_id' do
    context 'with valid issue ID' do
      it 'returns true for standard format (ABC-123)' do
        expect(described_class.validate_issue_id('ABC-123')).to be true
      end

      it 'returns true for single letter format (A-123)' do
        expect(described_class.validate_issue_id('A-123')).to be true
      end

      it 'returns true for long prefix format (ABCDEF-123)' do
        expect(described_class.validate_issue_id('ABCDEF-123')).to be true
      end
    end

    context 'with invalid issue ID' do
      it 'raises an error for ID without hyphen' do
        expect { described_class.validate_issue_id('ABC123') }.to raise_error(ArgumentError, /Invalid issue ID format/)
      end

      it 'raises an error for ID without numbers' do
        expect { described_class.validate_issue_id('ABC-') }.to raise_error(ArgumentError, /Invalid issue ID format/)
      end

      it 'raises an error for ID without letters' do
        expect { described_class.validate_issue_id('123') }.to raise_error(ArgumentError, /Invalid issue ID format/)
      end

      it 'raises an error for ID with special characters' do
        expect do
          described_class.validate_issue_id('ABC!-123')
        end.to raise_error(ArgumentError, /Invalid issue ID format/)
      end
    end
  end

  describe '.validate_priority' do
    context 'with valid priority' do
      it 'returns true for 0' do
        expect(described_class.validate_priority(0)).to be true
      end

      it 'returns true for valid values (0-4)' do
        (0..4).each do |priority|
          expect(described_class.validate_priority(priority)).to be true
        end
      end

      it 'converts strings to integers' do
        expect(described_class.validate_priority('3')).to be true
      end
    end

    context 'with invalid priority' do
      it 'raises an error for negative values' do
        expect { described_class.validate_priority(-1) }.to raise_error(ArgumentError, /Invalid priority value/)
      end

      it 'raises an error for values greater than 4' do
        expect { described_class.validate_priority(5) }.to raise_error(ArgumentError, /Invalid priority value/)
      end
    end
  end

  describe '.sanitize_string' do
    it 'returns nil for nil input' do
      expect(described_class.sanitize_string(nil)).to be_nil
    end

    it 'removes control characters' do
      expect(described_class.sanitize_string("test\x00string")).to eq('teststring')
    end

    it 'trims whitespace' do
      expect(described_class.sanitize_string('  test  ')).to eq('test')
    end

    it 'converts non-string values to strings' do
      expect(described_class.sanitize_string(123)).to eq('123')
    end
  end

  describe '.validate_team_name' do
    it 'returns sanitized team name for valid input' do
      expect(described_class.validate_team_name('Engineering')).to eq('Engineering')
    end

    it 'trims whitespace' do
      expect(described_class.validate_team_name('  Engineering  ')).to eq('Engineering')
    end

    it 'raises an error for blank input' do
      expect { described_class.validate_team_name('') }.to raise_error(ArgumentError, /Team name cannot be blank/)
      expect { described_class.validate_team_name('   ') }.to raise_error(ArgumentError, /Team name cannot be blank/)
    end
  end

  describe '.validate_title' do
    it 'returns sanitized title for valid input' do
      expect(described_class.validate_title('Fix login issue')).to eq('Fix login issue')
    end

    it 'trims whitespace' do
      expect(described_class.validate_title('  Fix login issue  ')).to eq('Fix login issue')
    end

    it 'raises an error for blank input' do
      expect { described_class.validate_title('') }.to raise_error(ArgumentError, /Title cannot be blank/)
      expect { described_class.validate_title('   ') }.to raise_error(ArgumentError, /Title cannot be blank/)
    end
  end

  describe '.validate_description' do
    it 'returns sanitized description for valid input' do
      expect(described_class.validate_description('This is a description')).to eq('This is a description')
    end

    it 'returns nil for nil input' do
      expect(described_class.validate_description(nil)).to be_nil
    end

    it 'trims whitespace' do
      expect(described_class.validate_description('  This is a description  ')).to eq('This is a description')
    end
  end

  describe '.validate_comment_body' do
    it 'returns sanitized body for valid input' do
      expect(described_class.validate_comment_body('This is a comment')).to eq('This is a comment')
    end

    it 'trims whitespace' do
      expect(described_class.validate_comment_body('  This is a comment  ')).to eq('This is a comment')
    end

    it 'raises an error for blank input' do
      expect { described_class.validate_comment_body('') }.to raise_error(ArgumentError, /Comment body cannot be blank/)
      expect do
        described_class.validate_comment_body('   ')
      end.to raise_error(ArgumentError, /Comment body cannot be blank/)
    end
  end

  describe '.validate_email' do
    context 'with valid email addresses' do
      it 'returns true for standard email format' do
        expect(described_class.validate_email('user@example.com')).to be true
      end

      it 'returns true for email with plus sign' do
        expect(described_class.validate_email('user+tag@example.com')).to be true
      end

      it 'returns true for email with subdomain' do
        expect(described_class.validate_email('user@sub.example.com')).to be true
      end
    end

    context 'with invalid email addresses' do
      it 'raises an error for email without @ symbol' do
        expect do
          described_class.validate_email('userexample.com')
        end.to raise_error(ArgumentError, /Invalid email format/)
      end

      it 'raises an error for email without domain' do
        expect { described_class.validate_email('user@') }.to raise_error(ArgumentError, /Invalid email format/)
      end

      it 'raises an error for email with invalid characters' do
        expect do
          described_class.validate_email('user@example.com!')
        end.to raise_error(ArgumentError, /Invalid email format/)
      end
    end
  end

  describe '.validate_limit' do
    it 'returns the limit for valid positive numbers' do
      expect(described_class.validate_limit(10)).to eq(10)
    end

    it 'converts strings to integers' do
      expect(described_class.validate_limit('20')).to eq(20)
    end

    it 'caps limits at 100' do
      expect(described_class.validate_limit(150)).to eq(100)
    end

    it 'raises an error for zero or negative values' do
      expect { described_class.validate_limit(0) }.to raise_error(ArgumentError, /Limit must be a positive number/)
      expect { described_class.validate_limit(-5) }.to raise_error(ArgumentError, /Limit must be a positive number/)
    end
  end
end
