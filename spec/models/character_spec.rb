require "spec_helper"

RSpec.describe Character do
  describe "validations" do
    it "requires valid group" do
      character = build(:character)
      expect(character).to be_valid
      character.character_group_id = 0
      expect(character).not_to be_valid
    end

    it "requires valid default icon" do
      icon = create(:icon)
      character = build(:character)
      expect(character).to be_valid
      character.default_icon = icon
      expect(character).not_to be_valid
    end

    it "requires valid galleries" do
      gallery = create(:gallery)
      character = create(:character)
      expect(character).to be_valid
      character.gallery_ids = [gallery.id]
      expect(character).not_to be_valid
    end
  end

  it "uniqs gallery images" do
    character = create(:character)
    icon = create(:icon, user: character.user)
    gallery = create(:gallery, user: character.user)
    gallery.icons << icon
    expect(gallery.icons.map(&:id)).to eq([icon.id])
    character.galleries << gallery
    gallery = create(:gallery, user: character.user)
    gallery.icons << icon
    expect(gallery.icons.map(&:id)).to eq([icon.id])
    character.galleries << gallery
    expect(character.galleries.size).to eq(2)
    expect(character.icons.map(&:id)).to eq([icon.id])
  end

  describe "#editable_by?" do
    it "should be false for random user" do
      character = create(:character)
      user = create(:user)
      expect(character).not_to be_editable_by(user)
    end

    it "should be true for owner" do
      character = create(:character)
      expect(character).to be_editable_by(character.user)
    end

    it "should be true for admin" do
      character = create(:character)
      admin = create(:admin_user)
      expect(character).to be_editable_by(admin)
    end
  end

  describe "#ungrouped_gallery_ids" do
    it "returns only galleries not added by groups" do
      user = create(:user)
      character = create(:character, user: user)
      gallery1 = create(:gallery, user: user)
      gallery2 = create(:gallery, user: user)

      CharactersGallery.create(character: character, gallery: gallery1)
      CharactersGallery.create(character: character, gallery: gallery2, added_by_group: true)

      character.reload
      expect(character.gallery_ids).to match_array([gallery1.id, gallery2.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery1.id])
    end
  end

  describe "#ungrouped_gallery_ids=" do
    it "adds unattached galleries" do
      user = create(:user)
      character = create(:character, user: user)
      gallery = create(:gallery, user: user)

      expect(character.gallery_ids).to eq([])
      expect(character.ungrouped_gallery_ids).to eq([])
      character.ungrouped_gallery_ids = [gallery.id]
      character.save!

      character.reload
      expect(character.characters_galleries.map(&:added_by_group?)).to match_array([false])
      expect(character.gallery_ids).to match_array([gallery.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery.id])
    end

    it "sets already-attached galleries to not be added_by_group" do
      # does not add a new attachment
      user = create(:user)
      group = create(:gallery_group)
      character = create(:character, gallery_groups: [group], user: user)
      gallery = create(:gallery, gallery_groups: [group], user: user)

      character.reload
      expect(character.gallery_ids).to match_array([gallery.id])
      expect(character.ungrouped_gallery_ids).to match_array([])

      character.ungrouped_gallery_ids = [gallery.id]
      character.save!
      character.reload

      expect(character.gallery_ids).to match_array([gallery.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery.id])
      expect(character.characters_galleries.map(&:added_by_group)).to match_array([false])
    end

    it "removes associated galleries when not present only if not also present in groups, otherwise sets flag" do
      # does not remove gallery_manual when not told to
      # sets flag on gallery_both to be added_by_group
      # does not remove gallery_auto despite not being present
      user = create(:user)
      group = create(:gallery_group)
      character = create(:character, gallery_groups: [group], user: user)
      gallery_manual = create(:gallery, user: user)
      gallery_both = create(:gallery, gallery_groups: [group], user: user)
      gallery_automatic = create(:gallery, gallery_groups: [group], user: user)

      CharactersGallery.create(character: character, gallery: gallery_manual)
      character.characters_galleries.where(gallery_id: gallery_both.id).update_all(added_by_group: false)

      character.reload
      expect(character.gallery_ids).to match_array([gallery_manual.id, gallery_both.id, gallery_automatic.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery_manual.id, gallery_both.id])

      character.ungrouped_gallery_ids = [gallery_manual.id]
      character.save!

      character.reload
      expect(character.gallery_ids).to match_array([gallery_manual.id, gallery_both.id, gallery_automatic.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery_manual.id])
      expect(character.characters_galleries.find_by(gallery_id: gallery_both.id)).to be_added_by_group
    end

    it "deletes manually-added galleries when not present" do
      user = create(:user)
      gallery = create(:gallery, user: user)
      character = create(:character, user: user, galleries: [gallery])

      character.reload
      expect(character.gallery_ids).to eq([gallery.id])
      expect(character.ungrouped_gallery_ids).to eq([gallery.id])
      character.ungrouped_gallery_ids = []
      character.save!

      character.reload
      expect(character.gallery_ids).to eq([])
    end

    it "does nothing if unchanged" do
      # does not remove or change the status of any of: gallery_manual, gallery_both, gallery_auto
      user = create(:user)
      group = create(:gallery_group)
      character = create(:character, gallery_groups: [group], user: user)
      gallery_manual = create(:gallery, user: user)
      gallery_both = create(:gallery, gallery_groups: [group], user: user)
      gallery_automatic = create(:gallery, gallery_groups: [group], user: user)

      CharactersGallery.create(character: character, gallery: gallery_manual)
      character.characters_galleries.where(gallery_id: gallery_both.id).update_all(added_by_group: false)

      character.reload
      expect(character.gallery_ids).to match_array([gallery_manual.id, gallery_both.id, gallery_automatic.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery_manual.id, gallery_both.id])

      character.ungrouped_gallery_ids = [gallery_manual.id, gallery_both.id]
      character.save!

      character.reload
      expect(character.gallery_ids).to match_array([gallery_manual.id, gallery_both.id, gallery_automatic.id])
      expect(character.ungrouped_gallery_ids).to match_array([gallery_manual.id, gallery_both.id])
    end

    ['before', 'after'].each do |time|
      context "combined #{time} gallery_group_ids" do
        def process_changes(obj, gallery_group_ids, ungrouped_gallery_ids, time)
          if time == 'before'
            obj.ungrouped_gallery_ids = ungrouped_gallery_ids
            obj.gallery_group_ids = gallery_group_ids
          else
            obj.gallery_group_ids = gallery_group_ids
            obj.ungrouped_gallery_ids = ungrouped_gallery_ids
          end
        end

        it "supports adding a gallery at the same time as removing its group" do
          user = create(:user)
          group = create(:gallery_group)
          gallery = create(:gallery, user: user, gallery_groups: [group])
          character = create(:character, user: user, gallery_groups: [group])
          expect(character.reload.galleries).to match_array([gallery])

          process_changes(character, [], [gallery.id], time)
          character.save

          character.reload
          expect(character.galleries).to match_array([gallery])
          expect(character.ungrouped_gallery_ids).to match_array([gallery.id])
          expect(character.gallery_groups).to match_array([])
        end

        it "supports adding a gallery at the same time as swapping its group" do
          user = create(:user)
          group1 = create(:gallery_group)
          group2 = create(:gallery_group)
          gallery = create(:gallery, user: user, gallery_groups: [group1, group2])
          character = create(:character, user: user, gallery_groups: [group1])
          expect(character.reload.galleries).to match_array([gallery])

          process_changes(character, [group2.id], [gallery.id], time)
          character.save

          character.reload
          expect(character.galleries).to match_array([gallery])
          expect(character.ungrouped_gallery_ids).to match_array([gallery.id])
          expect(character.gallery_groups).to match_array([group2])
        end

        it "keeps a gallery when removing at the same time as adding its group" do
          user = create(:user)
          group = create(:gallery_group)
          gallery = create(:gallery, user: user, gallery_groups: [group])
          character = create(:character, user: user, galleries: [gallery])
          expect(character.reload.galleries).to match_array([gallery])

          process_changes(character, [group.id], [], time)
          character.save

          character.reload
          expect(character.galleries).to match_array([gallery])
          expect(character.ungrouped_gallery_ids).to match_array([])
          expect(character.gallery_groups).to match_array([group])
        end

        it "keeps a gallery when removing at the same time as swapping its group" do
          user = create(:user)
          group1 = create(:gallery_group)
          group2 = create(:gallery_group)
          gallery = create(:gallery, user: user, gallery_groups: [group1, group2])
          character = create(:character, user: user, galleries: [gallery], gallery_groups: [group1])
          expect(character.reload.galleries).to match_array([gallery])

          process_changes(character, [group2.id], [], time)
          character.save

          character.reload
          expect(character.galleries).to match_array([gallery])
          expect(character.ungrouped_gallery_ids).to match_array([])
          expect(character.gallery_groups).to match_array([group2])
        end
      end
    end
  end

  # from Taggable concern; duplicated between PostSpec, CharacterSpec, GallerySpec
  context "tags" do
    let(:taggable) { create(:character) }
    ['gallery_group'].each do |type|
      it "creates new #{type} tags if they don't exist" do
        taggable.send(type + '_ids=', ['_tag'])
        expect(taggable.send(type + 's').map(&:name)).to match_array(['tag'])
        taggable.save
        taggable.reload
        tags = taggable.send(type + 's')
        tag_ids = taggable.send(type + '_ids')
        expect(tags.map(&:name)).to match_array(['tag'])
        expect(tags.map(&:user)).to match_array([taggable.user])
      end

      it "uses extant tags with same name and type for #{type}" do
        tag = create(type)
        old_user = tag.user
        taggable.send(type + '_ids=', ['_' + tag.name])
        taggable.save
        taggable.reload
        tags = taggable.send(type + 's')
        expect(tags).to match_array([tag])
        expect(tags.map(&:user)).to match_array([old_user])
      end

      it "does not use extant tags of a different type with same name for #{type}" do
        name = "Example Tag"
        tag = create(:tag, type: 'NonexistentTag', name: name)
        taggable.send(type + '_ids=', ['_' + name])
        taggable.save
        taggable.reload
        tags = taggable.send(type + 's')
        tag_ids = taggable.send(type + '_ids')
        expect(tags.map(&:name)).to match_array([name])
        expect(tags.map(&:user)).to match_array([taggable.user])
        expect(tags).not_to include(tag)
        expect(tag_ids).to match_array(tags.map(&:id))
      end

      it "uses extant #{type} tags by id" do
        tag = create(type)
        old_user = tag.user
        taggable.send(type + '_ids=', [tag.id.to_s])
        taggable.save
        taggable.reload
        tags = taggable.send(type + 's')
        tag_ids = taggable.send(type + '_ids')
        expect(tags).to match_array([tag])
        expect(tags.map(&:user)).to match_array([old_user])
        expect(tag_ids).to match_array([tag.id])
      end

      it "removes #{type} tags when not in list given" do
        tag = create(type)
        taggable.send(type + 's=', [tag])
        taggable.save
        taggable.reload
        expect(taggable.send(type + 's')).to match_array([tag])
        taggable.send(type + '_ids=', [])
        taggable.save
        taggable.reload
        expect(taggable.send(type + 's')).to eq([])
        expect(taggable.send(type + '_ids')).to eq([])
      end

      it "only adds #{type} tags once if given multiple times" do
        name = 'Example Tag'
        tag = create(type, name: name)
        old_user = tag.user
        taggable.send(type + '_ids=', ['_' + name, '_' + name, tag.id.to_s, tag.id.to_s])
        taggable.save
        taggable.reload
        tags = taggable.send(type + 's')
        tag_ids = taggable.send(type + '_ids')
        expect(tags).to match_array([tag])
        expect(tags.map(&:user)).to match_array([old_user])
        expect(tag_ids).to match_array([tag.id])
      end

      it "orders #{type} tag joins by order added to model" do
        tag1 = create(type)
        tag2 = create(type)
        tag3 = create(type)
        tag4 = create(type)

        taggable.send(type + '_ids=', [tag3.id, '_fake1', '_'+tag1.name, '_fake2', tag4.id, 'broken'])
        taggable.save
        taggable.reload
        tags = taggable.send(type + 's').order('character_tags.id')
        expect(tags[0]).to eq(tag3)
        expect(tags[2]).to eq(tag1)
        expect(tags[4]).to eq(tag4)
        expect(tags.map(&:name)).to eq([tag3.name, 'fake1', tag1.name, 'fake2', tag4.name])

        taggable.send(type + '_ids=', taggable.send(type + '_ids') + ['_'+tag2.name, '_fake3', '_fake4'])
        taggable.save
        taggable.reload
        tags = taggable.send(type + 's').order('character_tags.id')
        tag_ids = taggable.send(type + '_ids')
        expect(tags[0]).to eq(tag3)
        expect(tags[2]).to eq(tag1)
        expect(tags[5]).to eq(tag2)
        expect(tags.map(&:name)).to eq([tag3.name, 'fake1', tag1.name, 'fake2', tag4.name, tag2.name, 'fake3', 'fake4'])
      end
    end
  end
end
