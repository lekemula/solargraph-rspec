# frozen_string_literal: true

RSpec.describe Solargraph::Rspec::Gems do
  let(:api_map) { Solargraph::ApiMap.new }
  let(:library) { Solargraph::Library.new }
  let(:filename) { File.expand_path('spec/models/some_namespace/transaction_spec.rb') }

  describe 'rspec' do
    it 'finds definition of DSL methods' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          context 'some context' do
            let(:something) { 'something' }

            it 'should do something' do
            end
          end

          context 'another context' do
          end
        end
      RUBY

      expect(definition_at(filename, [1, 3])).to include('RSpec::Core::ExampleGroup.context')
      expect(definition_at(filename, [2, 5])).to include('RSpec::Core::MemoizedHelpers::ClassMethods#let')
      expect(definition_at(filename, [4, 5])).to include('RSpec::Core::ExampleGroup.it')
    end

    it 'completes RSpec::Matchers methods' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          context 'some context' do
            it 'should do something' do
              expect(subject).to be_a_
            end
          end
        end
      RUBY

      expect(completion_at(filename, [3, 29])).to include('be_a_kind_of')
    end

    it 'completes normal ruby class methods' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          def self.my_class_method
          end

          my_clas

          context 'some context' do
            my_clas
          end
        end
      RUBY

      expect(completion_at(filename, [4, 9])).to include('my_class_method')
      expect(completion_at(filename, [7, 11])).to include('my_class_method') # inherit from parent context
    end

    it 'completes RSpec DSL methods' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          desc
          cont
          xi
          fex
          fdes

          context 'some context' do
            desc
            cont
            xi
            fex
            fdes
          end
        end
      RUBY

      # parent context
      # https://github.com/rspec/rspec/pull/200
      if Gem.loaded_specs['rspec-core'].version > Gem::Version.new('3.13.3')
        expect(completion_at(filename, [1, 7])).to include('describe')
        expect(completion_at(filename, [2, 7])).to include('context')
        expect(completion_at(filename, [5, 7])).to include('fdescribe')
      end
      expect(completion_at(filename, [3, 7])).to include('xit')
      expect(completion_at(filename, [4, 7])).to include('fexample')

      # child/nexted context
      # https://github.com/rspec/rspec/pull/200
      if Gem.loaded_specs['rspec-core'].version > Gem::Version.new('3.13.3')
        expect(completion_at(filename, [8, 7])).to include('describe')
        expect(completion_at(filename, [9, 7])).to include('context')
        expect(completion_at(filename, [12, 7])).to include('fdescribe')
      end
      expect(completion_at(filename, [10, 7])).to include('xit')
      expect(completion_at(filename, [11, 7])).to include('fexample')
    end
  end

  describe 'shoulda-matchers' do
    it 'completes active-model matchers' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          it 'completes active-model matchers' do
            allow_valu
            have_secur
            validate_a
            validate_a
            validate_c
            validate_e
            validate_i
            validate_l
            validate_n
            validate_p
          end
        end
      RUBY

      expect(completion_at(filename, [2, 15])).to include('allow_value')
      expect(completion_at(filename, [3, 15])).to include('have_secure_password')
      expect(completion_at(filename, [4, 15])).to include('validate_absence_of')
      expect(completion_at(filename, [5, 15])).to include('validate_acceptance_of')
      expect(completion_at(filename, [6, 15])).to include('validate_confirmation_of')
      expect(completion_at(filename, [7, 15])).to include('validate_exclusion_of')
      expect(completion_at(filename, [8, 15])).to include('validate_inclusion_of')
      expect(completion_at(filename, [9, 15])).to include('validate_length_of')
      expect(completion_at(filename, [10, 15])).to include('validate_numericality_of')
      expect(completion_at(filename, [11, 15])).to include('validate_presence_of')
    end

    it 'completes active-record matchers' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          it 'completes controller matchers' do
            accept_nested_attributes
            belon
            define_enum
            have_and_belong_to_
            have_delegated_
            have_db_co
            have_db_i
            have_implicit_order_co
            have_
            have_many_atta
            have
            have_one_atta
            have_readonly_attri
            have_rich_
            seria
            validate_uniquenes
            norma
            enc
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('accept_nested_attributes_for')
      expect(completion_at(filename, [3, 5])).to include('belong_to')
      expect(completion_at(filename, [4, 5])).to include('define_enum_for')
      expect(completion_at(filename, [5, 5])).to include('have_and_belong_to_many')
      # expect(completion_at(filename, [6, 5])).to include('have_delegated_type')
      expect(completion_at(filename, [7, 5])).to include('have_db_column')
      expect(completion_at(filename, [8, 5])).to include('have_db_index')
      expect(completion_at(filename, [9, 5])).to include('have_implicit_order_column')
      expect(completion_at(filename, [10, 5])).to include('have_many')
      expect(completion_at(filename, [11, 5])).to include('have_many_attached')
      expect(completion_at(filename, [12, 5])).to include('have_one')
      expect(completion_at(filename, [13, 5])).to include('have_one_attached')
      expect(completion_at(filename, [14, 5])).to include('have_readonly_attribute')
      expect(completion_at(filename, [15, 5])).to include('have_rich_text')
      expect(completion_at(filename, [16, 5])).to include('serialize')
      expect(completion_at(filename, [17, 5])).to include('validate_uniqueness_of')
      # expect(completion_at(filename, [18, 5])).to include('normalize')
      # expect(completion_at(filename, [19, 5])).to include('encrypt')
    end

    it 'completes controller matchers' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          it 'completes controller matchers' do
            filter_pa
            per
            redirect
            render_templ
            render_with_lay
            rescue_f
            respond_w
            ro
            set_sess
            set_fl
            use_after_act
            use_around_act
            use_before_act
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('filter_param')
      expect(completion_at(filename, [3, 5])).to include('permit')
      expect(completion_at(filename, [4, 5])).to include('redirect_to')
      expect(completion_at(filename, [5, 5])).to include('render_template')
      expect(completion_at(filename, [6, 5])).to include('render_with_layout')
      expect(completion_at(filename, [7, 5])).to include('rescue_from')
      expect(completion_at(filename, [8, 5])).to include('respond_with')
      expect(completion_at(filename, [9, 5])).to include('route')
      expect(completion_at(filename, [10, 5])).to include('set_session')
      expect(completion_at(filename, [11, 5])).to include('set_flash')
      expect(completion_at(filename, [12, 5])).to include('use_after_action')
      expect(completion_at(filename, [13, 5])).to include('use_around_action')
      expect(completion_at(filename, [14, 5])).to include('use_before_action')
    end
  end

  describe 'rspec-mocks' do
    it 'completes methods from rspec-mocks' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          let(:something) { double }

          it 'should do something' do
            allow(something).to rec
            allow(double).to receive_me
            my_double = doub
            my_double = inst
          end
        end
      RUBY

      expect(completion_at(filename, [4, 26])).to include('receive')
      expect(completion_at(filename, [5, 30])).to include('receive_message_chain')
      expect(completion_at(filename, [6, 18])).to include('double')
      expect(completion_at(filename, [7, 18])).to include('instance_double')
    end
  end

  describe 'rspec-rails' do
    # A model spec is a thin wrapper for an ActiveSupport::TestCase
    # See: https://api.rubyonrails.org/v5.2.8.1/classes/ActiveSupport/Testing/Assertions.html
    it 'completes model methods' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          it 'should do something' do
            assert_ch
            assert_di
            assert_no
            assert_no
            assert_no
            assert_no
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('assert_changes')
      expect(completion_at(filename, [3, 5])).to include('assert_difference')
      expect(completion_at(filename, [4, 5])).to include('assert_no_changes')
      expect(completion_at(filename, [5, 5])).to include('assert_no_difference')
      expect(completion_at(filename, [6, 5])).to include('assert_not')
      expect(completion_at(filename, [7, 5])).to include('assert_nothing_raised')
    end

    # @see [ActionController::TestCase::Behavior]
    it 'completes controller methods' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :controller do
          it 'should do something' do
            build_re
            controll
            delet
            generate
            ge
            hea
            patc
            pos
            proces
            pu
            query_pa
            setup_co
            requ
            request.ho
            respo
            response.hea
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('build_response')
      expect(completion_at(filename, [3, 5])).to include('controller_class_name')
      expect(completion_at(filename, [4, 5])).to include('delete')
      expect(completion_at(filename, [5, 5])).to include('generated_path')
      expect(completion_at(filename, [6, 5])).to include('get')
      expect(completion_at(filename, [7, 5])).to include('head')
      expect(completion_at(filename, [8, 5])).to include('patch')
      expect(completion_at(filename, [9, 5])).to include('post')
      expect(completion_at(filename, [10, 5])).to include('process')
      expect(completion_at(filename, [11, 5])).to include('put')
      expect(completion_at(filename, [12, 5])).to include('query_parameter_names')
      expect(completion_at(filename, [13, 5])).to include('setup_controller_request_and_response')
      # Test lib/solargraph/rspec/annotations.rb
      expect(completion_at(filename, [14, 5])).to include('request')
      expect(completion_at(filename, [15, 13])).to include('host') # request.host
      expect(completion_at(filename, [16, 5])).to include('response')
      # The below expecattion does not work anymore because ActionDispatch::Response conflicts with Airborne#response
      # expect(completion_at(filename, [17, 14])).to include('headers') # response.body
    end

    it 'completes ActiveSupport assertions' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          it 'should do something' do
            assert_cha
            assert_dif
            assert_no_
            assert_no_
            assert_no
            assert_not
            assert_rai
            assert_rai
            assert_tem
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('assert_changes')
      expect(completion_at(filename, [3, 5])).to include('assert_difference')
      expect(completion_at(filename, [4, 5])).to include('assert_no_changes')
      expect(completion_at(filename, [5, 5])).to include('assert_no_difference')
      expect(completion_at(filename, [6, 5])).to include('assert_not')
      expect(completion_at(filename, [7, 5])).to include('assert_nothing_raised')
      # expect(completion_at(filename, [8, 5])).to include('assert_raise')
      expect(completion_at(filename, [9, 5])).to include('assert_raises')
      expect(completion_at(filename, [10, 5])).to include('assert_template')
    end

    it 'completes ActiveSupport helpers' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          it 'should do something' do
            after_teardo
            freeze_ti
            trav
            travel_ba
            travel_
            file_fix
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('after_teardown')
      expect(completion_at(filename, [3, 5])).to include('freeze_time')
      expect(completion_at(filename, [4, 5])).to include('travel')
      expect(completion_at(filename, [5, 5])).to include('travel_back')
      expect(completion_at(filename, [6, 5])).to include('travel_to')
      expect(completion_at(filename, [7, 5])).to include('file_fixture')
    end

    it 'completes routing helpers' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          it 'should do something' do
            after_teardo
            freeze_ti
            trav
            travel_ba
            travel_
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('after_teardown')
      expect(completion_at(filename, [3, 5])).to include('freeze_time')
      expect(completion_at(filename, [4, 5])).to include('travel')
      expect(completion_at(filename, [5, 5])).to include('travel_back')
    end

    it 'completes mailer methods' do
      pending("FIXME: Why it doesn't work?")
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :mailer do
          it 'should do something' do
            assert_emai
            assert_enqu
            assert_no_e
            assert_no_e
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('assert_emails')
      expect(completion_at(filename, [3, 5])).to include('assert_enqueued_emails')
      expect(completion_at(filename, [4, 5])).to include('assert_no_emails')
      expect(completion_at(filename, [5, 5])).to include('assert_no_enqueued_emails')
    end

    it 'completes matchers from rspec-rails' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          it 'should do something' do
            be_a_
            render_templ
            redirect
            route
            be_routa
            have_http_sta
            match_ar
            have_been_enque
            have_enqueued_
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('be_a_new')
      expect(completion_at(filename, [3, 5])).to include('render_template')
      expect(completion_at(filename, [4, 5])).to include('redirect_to')
      # expect(completion_at(filename, [5, 5])).to include('route_to')
      # expect(completion_at(filename, [6, 5])).to include('be_routable')
      expect(completion_at(filename, [7, 5])).to include('have_http_status')
      expect(completion_at(filename, [8, 5])).to include('match_array')
      expect(completion_at(filename, [9, 5])).to include('have_been_enqueued')
      expect(completion_at(filename, [10, 5])).to include('have_enqueued_job')
    end
  end

  describe 'rspec-sidekiq' do
    it 'completes sidekiq matchers' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :model do
          it 'completes controller matchers' do
            enqueue_sidekiq
            have_enqueued_sidekiq
            be_processe
            be_retry
            save_backt
            be_un
            be_expire
            be_del
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('enqueue_sidekiq_job')
      expect(completion_at(filename, [3, 5])).to include('have_enqueued_sidekiq_job')
      expect(completion_at(filename, [4, 5])).to include('be_processed_in')
      expect(completion_at(filename, [5, 5])).to include('be_retryable')
      expect(completion_at(filename, [6, 5])).to include('save_backtrace')
      expect(completion_at(filename, [7, 5])).to include('be_unique')
      expect(completion_at(filename, [8, 5])).to include('be_expired_in')
      expect(completion_at(filename, [9, 5])).to include('be_delayed')
    end
  end

  describe 'webmock' do
    it 'completes webmock helpers' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :controller do
          it 'does something' do
            stub_requ
            a_requ
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('stub_request')
      expect(completion_at(filename, [3, 5])).to include('a_request')
    end

    it 'completes webmock matchers' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :controller do
          it 'does something' do
            expect(a_request(:post, "www.something.com")).to have_bee
            expect(a_request(:post, "www.something.com")).to have_no
            expect(stub).to have_been_req
            expect(WebMock).to have_requ
            expect(WebMock).to have_not_
            assert_req
            assert_not_req
          end
        end
      RUBY

      expect(completion_at(filename, [2, 60])).to include('have_been_made')
      expect(completion_at(filename, [3, 60])).to include('have_not_been_made')
      expect(completion_at(filename, [4, 31])).to include('have_been_requested')
      expect(completion_at(filename, [5, 31])).to include('have_requested')
      expect(completion_at(filename, [6, 31])).to include('have_not_requested')
      expect(completion_at(filename, [7, 5])).to include('assert_requested')
      expect(completion_at(filename, [8, 5])).to include('assert_not_requested')
    end
  end

  describe 'airborne' do
    it 'completes airborne matchers' do
      load_string filename, <<~RUBY
        RSpec.describe SomeNamespace::Transaction, type: :controller do
          it 'does something' do
            expect_jso
            expect_jso
            expect_jso
            expect_jso
            expect_sta
            expect_hea
            expect_hea
          end
        end
      RUBY

      expect(completion_at(filename, [2, 5])).to include('expect_json_types')
      expect(completion_at(filename, [3, 5])).to include('expect_json')
      expect(completion_at(filename, [4, 5])).to include('expect_json_keys')
      # expect(completion_at(filename, [5, 5])).to include('expect_json_sizes')
      expect(completion_at(filename, [6, 5])).to include('expect_status')
      expect(completion_at(filename, [7, 5])).to include('expect_header')
      expect(completion_at(filename, [8, 5])).to include('expect_header_contains')
    end
  end
end
