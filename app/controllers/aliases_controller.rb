# frozen_string_literal: true
class AliasesController < ApplicationController
  before_filter :login_required
  before_filter :find_character
  before_filter :find_alias, only: :destroy

  def index
    @page_title = "Aliases: " + @character.name
    @aliases = @character.aliases.order('name asc')
  end

  def new
    @page_title = "New Alias: " + @character.name
    @alias = CharacterAlias.new(character: @character)
  end

  def create
    @alias = CharacterAlias.new(params[:character_alias])
    @alias.character = @character

    unless @alias.save
      flash.now[:error] = {}
      flash.now[:error][:message] = "Alias could not be created."
      flash.now[:error][:array] = @alias.errors.full_messages
      @page_title = "New Alias: " + @character.name
      render action: :new and return
    end

    flash[:success] = "Alias created."
    redirect_to character_aliases_path(@character)
  end

  def destroy
    @alias.destroy
    flash[:success] = "Alias removed."
    redirect_to character_aliases_path(@character)
  end

  private

  def find_character
    unless @character = Character.find_by_id(params[:character_id])
      flash[:error] = "Character could not be found."
      redirect_to characters_path and return
    end

    unless @character.user == current_user
      flash[:error] = "That is not your character."
      redirect_to characters_path and return
    end
  end

  def find_alias
    unless @alias = CharacterAlias.find_by_id(params[:id])
      flash[:error] = "Alias could not be found."
      redirect_to character_aliases_path(@character) and return
    end

    unless @alias.character_id == @character.id
      flash[:error] = "Alias could not be found for that character."
      redirect_to character_aliases_path(@character) and return
    end
  end
end