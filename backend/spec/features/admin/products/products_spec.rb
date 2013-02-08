require 'spec_helper'

describe "Products" do
  stub_authorization!

  context "as admin user" do
    before(:each) do
      visit spree.admin_path
    end

    context "listing products" do
      context "sorting" do
        before do
          create(:product, :name => 'apache baseball cap', :price => 10)
          create(:product, :name => 'zomg shirt', :price => 5)
        end

        it "should list existing products with correct sorting by name" do
          first(:link, "Products").click
          # Name ASC
          within_row(1) { page.should have_content('apache baseball cap') }
          within_row(2) { page.should have_content("zomg shirt") }

          # Name DESC
          click_link "admin_products_listing_name_title"
          within_row(1) { page.should have_content("zomg shirt")  }
          within_row(2) { page.should have_content('apache baseball cap') }
        end

        it "should list existing products with correct sorting by price" do
          first(:link, "Products").click

          # Name ASC (default)
          within_row(1) { page.should have_content('apache baseball cap') }
          within_row(2) { page.should have_content("zomg shirt") }

          # Price DESC
          click_link "admin_products_listing_price_title"
          within_row(1) { page.should have_content("zomg shirt") }
          within_row(2) { page.should have_content('apache baseball cap') }
        end
      end
    end

    context "searching products" do
      it "should be able to search deleted products", :js => true do
        create(:product, :name => 'apache baseball cap', :deleted_at => "2011-01-06 18:21:13")
        create(:product, :name => 'zomg shirt')

        first(:link, "Products").click
        page.should have_content("zomg shirt")
        page.should_not have_content("apache baseball cap")
        check "Show Deleted"
        click_icon :search
        page.should have_content("zomg shirt")
        page.should have_content("apache baseball cap")
        uncheck "Show Deleted"
        click_icon :search
        page.should have_content("zomg shirt")
        page.should_not have_content("apache baseball cap")
      end

      it "should be able to search products by their properties" do
        create(:product, :name => 'apache baseball cap', :sku => "A100")
        create(:product, :name => 'apache baseball cap2', :sku => "B100")
        create(:product, :name => 'zomg shirt')

        first(:link, "Products").click
        fill_in "q_name_cont", :with => "ap"
        click_icon :search
        page.should have_content("apache baseball cap")
        page.should have_content("apache baseball cap2")
        page.should_not have_content("zomg shirt")

        fill_in "q_variants_including_master_sku_cont", :with => "A1"
        click_icon :search
        page.should have_content("apache baseball cap")
        page.should_not have_content("apache baseball cap2")
        page.should_not have_content("zomg shirt")
      end
    end

    context "creating a new product from a prototype" do
      def build_option_type_with_values(name, values)
        ot = FactoryGirl.create(:option_type, :name => name)
        values.each do |val|
          ot.option_values.create({:name => val.downcase, :presentation => val}, :without_protection => true)
        end
        ot
      end

      let(:product_attributes) do
        # FactoryGirl.attributes_for is un-deprecated!
        #   https://github.com/thoughtbot/factory_girl/issues/274#issuecomment-3592054
        FactoryGirl.attributes_for(:simple_product)
      end

      let(:prototype) do
        size = build_option_type_with_values("size", %w(Small Medium Large))
        FactoryGirl.create(:prototype, :name => "Size", :option_types => [ size ])
      end

      let(:option_values_hash) do
        hash = {}
        prototype.option_types.each do |i|
          hash[i.id.to_s] = i.option_value_ids
        end
        hash
      end

      before(:each) do
        @option_type_prototype = prototype
        @property_prototype = create(:prototype, :name => "Random")
        first(:link, "Products").click
        click_link "admin_new_product"
        first('#new_product').should have_content("SKU")
      end

      it "should allow an admin to create a new product and variants from a prototype", :js => true do
        fill_in "product_name", :with => "Baseball Cap"
        fill_in "product_sku", :with => "B100"
        fill_in "product_price", :with => "100"
        fill_in "product_available_on", :with => "2012/01/24"
        select "Size", :from => "Prototype"
        check "Large"
        click_button "Create"
        page.should have_content("successfully created!")
        Spree::Product.last.variants.length.should == 1
      end

      it "should not display variants when prototype does not contain option types", :js => true do
        select "Random", :from => "Prototype"

        fill_in "product_name", :with => "Baseball Cap"

        page.should_not have_content("Variants")
      end

      it "should keep option values selected if validation fails", :js => true do
        select "Size", :from => "Prototype"
        check "Large"
        click_button "Create"
        page.should have_content("Name can't be blank")
        field_labeled("Size").should be_checked
        field_labeled("Large").should be_checked
        field_labeled("Small").should_not be_checked
      end

    end

    context "creating a new product", :js => true do
      before(:each) do
        first(:link, "Products").click
        click_link "admin_new_product"
        first('#new_product').should have_content("SKU")
      end

      it "should allow an admin to create a new product", :js => true do
        fill_in "product_name", :with => "Baseball Cap"
        fill_in "product_sku", :with => "B100"
        fill_in "product_price", :with => "100"
        fill_in "product_available_on", :with => "2012/01/24"
        click_button "Create"
        page.should have_content("successfully created!")
        fill_in "product_on_hand", :with => "100"
        click_button "Update"
        page.should have_content("successfully updated!")
      end

      it "should show validation errors", :js => true do
        click_button "Create"
        page.should have_content("Name can't be blank")
      end

      # Regression test for #2097
      it "can set the count on hand to a null value", :js => true do
        fill_in "product_name", :with => "Baseball Cap"
        fill_in "product_price", :with => "100"
        click_button "Create"
        page.should have_content("successfully created!")
        fill_in "product_on_hand", :with => ""
        click_button "Update"
        page.should_not have_content("spree_products.count_on_hand may not be NULL")
        page.should have_content("successfully updated!")
      end
    end

    context "cloning a product", :js => true do
      it "should allow an admin to clone a product" do
        create(:product)

        first(:link, "Products").click
        within_row(1) do
          click_icon :copy
        end

        page.should have_content("Product has been cloned")
      end

      context "cloning a deleted product" do
        it "should allow an admin to clone a deleted product" do
          create(:product, :name => "apache baseball cap")

          first(:link, "Products").click
          check "Show Deleted"
          click_button "Search"

          page.should have_content("apache baseball cap")

          within_row(1) do
            click_icon :copy
          end

          page.should have_content("Product has been cloned")
        end
      end
    end

    context 'updating a product', :js => true do
      let(:product) { create(:product) }

      it 'should parse correctly available_on' do
        visit spree.admin_product_path(product)
        fill_in "product_available_on", :with => "2012/12/25"
        click_button "Update"
        page.should have_content("successfully updated!")
        Spree::Product.last.available_on.should == 'Tue, 25 Dec 2012 00:00:00 UTC +00:00'
      end
    end

  end
end
